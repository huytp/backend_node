class VpnConnection < ApplicationRecord
  belongs_to :entry_node, class_name: 'Node', foreign_key: 'entry_node_id'
  belongs_to :exit_node, class_name: 'Node', foreign_key: 'exit_node_id'
  has_many :traffic_records, dependent: :destroy

  validates :user_address, presence: true
  validates :connection_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[connected disconnected] }

  enum status: {
    connected: 'connected',
    disconnected: 'disconnected'
  }

  before_validation :generate_connection_id, on: :create

  def check_reward_eligibility_on_disconnect
    # Khi session kết thúc, kiểm tra reward eligibility cho các traffic records

    Rails.logger.info("VPN session ended - checking reward eligibility for connection: #{connection_id}")

    # Lấy tất cả traffic records của session này
    traffic_records.each do |traffic_record|
      # Xác định node (entry hoặc exit)
      node = traffic_record.node

      # Kiểm tra eligibility với request_source là session_end
      result = RewardEligibilityService.eligible_for_reward?(
        node,
        traffic_record,
        request_source: :session_end
      )

      # Cập nhật trạng thái vào record
      traffic_record.update!(
        reward_eligible: result[:eligible],
        eligibility_reason: result[:reason],
        request_source: 'session_end'
      )

      Rails.logger.info(
        "Traffic record #{traffic_record.id} - " \
        "Eligible: #{result[:eligible]}, Reason: #{result[:reason]}"
      )
    end
  end

  private

  def generate_connection_id
    self.connection_id ||= SecureRandom.uuid
  end
end

