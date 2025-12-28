class Epoch < ApplicationRecord
  has_many :traffic_records, dependent: :destroy
  has_many :rewards, dependent: :destroy

  validates :epoch_id, presence: true, uniqueness: true
  validates :start_time, presence: true
  validates :end_time, presence: true

  enum status: {
    pending: 'pending',
    processing: 'processing',
    committed: 'committed'
  }, _prefix: :epoch

  def committed?
    status == 'committed'
  end

  def calculate_rewards
    # Áp dụng công thức: reward = trafficMB × quality × reputation
    rewards_data = []

    traffic_records.group_by(&:node_id).each do |node_id, records|
      node = Node.find(node_id)
      total_traffic = records.sum(&:traffic_mb)
      quality = node.calculate_quality_score / 100.0
      reputation = (node.reputation_score || 50) / 100.0

      # Reward tính bằng token (wei equivalent, 1 token = 10^18 wei)
      reward_amount = (total_traffic * quality * reputation * 1000).to_i

      rewards_data << {
        node: node,
        amount: reward_amount,
        traffic_mb: total_traffic,
        quality: quality,
        reputation: node.reputation_score || 50,
        reward_amount: reward_amount
      }
    end

    rewards_data
  end

  def calculate_rewards_with_eligibility
    # Tính rewards CHỈ cho các traffic records đủ điều kiện
    rewards_data = []

    traffic_records.group_by(&:node_id).each do |node_id, records|
      node = Node.find(node_id)

      # Lọc chỉ các records đủ điều kiện reward
      eligible_records = records.select do |record|
        # Kiểm tra eligibility với request_source là epoch_end
        result = RewardEligibilityService.eligible_for_reward?(
          node,
          record,
          request_source: :epoch_end
        )

        # Cập nhật trạng thái vào record
        record.update!(
          reward_eligible: result[:eligible],
          eligibility_reason: result[:reason],
          request_source: 'epoch_end'
        )

        result[:eligible]
      end

      # Chỉ tính reward nếu có ít nhất 1 record đủ điều kiện
      next if eligible_records.empty?

      total_traffic = eligible_records.sum(&:traffic_mb)
      quality = node.calculate_quality_score / 100.0
      reputation = (node.reputation_score || 50) / 100.0

      # Reward tính bằng token (wei equivalent, 1 token = 10^18 wei)
      reward_amount = (total_traffic * quality * reputation * 1000).to_i

      rewards_data << {
        node: node,
        amount: reward_amount,
        traffic_mb: total_traffic,
        quality: quality,
        reputation: node.reputation_score || 50,
        reward_amount: reward_amount,
        eligible_records_count: eligible_records.count,
        total_records_count: records.count
      }
    end

    rewards_data
  end
end

