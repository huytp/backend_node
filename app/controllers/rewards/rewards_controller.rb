module Rewards
  class RewardsController < ApplicationController
    # GET /rewards/epoch/:id
    def epoch
      epoch = Epoch.find_by(epoch_id: params[:id])

      if epoch.nil?
        render json: { error: 'Epoch not found' }, status: :not_found
        return
      end

      render json: {
        epoch_id: epoch.epoch_id,
        start_time: epoch.start_time,
        end_time: epoch.end_time,
        merkle_root: epoch.merkle_root,
        status: epoch.status,
        total_traffic: epoch.total_traffic,
        node_count: epoch.node_count,
        committed: epoch.committed?
      }
    end

    # GET /rewards/proof
    def proof
      node_address = params[:node]
      epoch_id = params[:epoch] || params[:epoch_id]

      if node_address.blank? || epoch_id.blank?
        render json: { error: 'node and epoch parameters are required' }, status: :bad_request
        return
      end

      node = Node.find_by(address: node_address)
      epoch = Epoch.find_by(epoch_id: epoch_id)

      if node.nil?
        render json: { error: 'Node not found' }, status: :not_found
        return
      end

      if epoch.nil?
        render json: { error: 'Epoch not found' }, status: :not_found
        return
      end

      unless epoch.committed?
        render json: { error: 'Epoch not yet committed' }, status: :unprocessable_entity
        return
      end

      reward = Reward.find_by(node: node, epoch: epoch)

      if reward.nil?
        render json: { error: 'Reward not found for this node and epoch' }, status: :not_found
        return
      end

      begin
        proof_array = JSON.parse(reward.merkle_proof)

        render json: {
          epoch: epoch_id.to_i,
          node: node_address,
          amount: reward.amount,
          proof: proof_array,
          merkle_root: epoch.merkle_root
        }
      rescue JSON::ParserError => e
        render json: { error: 'Invalid merkle proof format' }, status: :internal_server_error
      end
    end

    # GET /rewards/epochs
    def epochs
      epochs = Epoch.order(epoch_id: :desc).limit(100)

      render json: epochs.map { |epoch|
        {
          epoch_id: epoch.epoch_id,
          start_time: epoch.start_time,
          end_time: epoch.end_time,
          merkle_root: epoch.merkle_root,
          status: epoch.status,
          total_traffic: epoch.total_traffic,
          node_count: epoch.node_count
        }
      }
    end

    # GET /rewards/current_epoch
    # Lấy epoch hiện tại (tự động tạo nếu chưa có)
    def current_epoch
      epoch = EpochService.get_or_create_current_epoch

      render json: {
        epoch_id: epoch.epoch_id,
        start_time: epoch.start_time,
        end_time: epoch.end_time,
        status: epoch.status,
        remaining_seconds: [(epoch.end_time - Time.current).to_i, 0].max
      }
    end

    # GET /rewards/verify/:epoch_id
    # Allow node to verify their reward calculation
    def verify
      node_address = params[:node] || request.headers['X-Node-Address']
      epoch_id = params[:epoch_id] || params[:id]

      if node_address.blank? || epoch_id.blank?
        render json: { error: 'node and epoch_id are required' }, status: :bad_request
        return
      end

      node = Node.find_by(address: node_address)
      epoch = Epoch.find_by(epoch_id: epoch_id)

      if node.nil? || epoch.nil?
        render json: { error: 'Node or epoch not found' }, status: :not_found
        return
      end

      # Get all traffic records for this node in this epoch
      traffic_records = epoch.traffic_records.where(node: node)

      # Calculate reward
      total_traffic = traffic_records.sum(&:traffic_mb)
      quality = node.calculate_quality_score
      reputation = node.reputation_score || 50
      calculated_reward = (total_traffic * (quality / 100.0) * (reputation / 100.0) * 1000).to_i

      # Get actual reward from database
      reward = Reward.find_by(node: node, epoch: epoch)
      actual_reward = reward ? reward.amount : 0

      # Kiểm tra eligibility cho từng traffic record
      traffic_records_with_eligibility = traffic_records.map do |r|
        {
          id: r.id,
          session_id: r.vpn_connection&.connection_id,
          traffic_mb: r.traffic_mb,
          signature: r.signature,
          created_at: r.created_at,
          reward_eligible: r.reward_eligible || false,
          eligibility_reason: r.eligibility_reason,
          request_source: r.request_source,
          ai_scored: r.ai_scored || false,
          ai_score: r.ai_score,
          has_anomaly: r.has_anomaly || false
        }
      end

      # Chỉ tính reward cho các records đủ điều kiện
      eligible_records = traffic_records.where(reward_eligible: true)
      eligible_traffic = eligible_records.sum(&:traffic_mb)
      eligible_reward = (eligible_traffic * (quality / 100.0) * (reputation / 100.0) * 1000).to_i

      render json: {
        epoch_id: epoch_id.to_i,
        node: node_address,
        traffic_records: traffic_records_with_eligibility,
        metrics: {
          total_traffic_mb: total_traffic,
          eligible_traffic_mb: eligible_traffic,
          quality_score: quality,
          reputation_score: reputation
        },
        reward_calculation: {
          formula: "trafficMB × (quality/100) × (reputation/100) × 1000",
          calculated_amount: calculated_reward,
          eligible_amount: eligible_reward,
          actual_amount: actual_reward,
          match: calculated_reward == actual_reward,
          eligible_records_count: eligible_records.count,
          total_records_count: traffic_records.count
        }
      }
    end

    # GET /rewards/eligibility/:traffic_record_id
    # Kiểm tra eligibility của một traffic record cụ thể
    def check_eligibility
      traffic_record_id = params[:traffic_record_id] || params[:id]
      request_source = params[:request_source]&.to_sym || :node_self

      traffic_record = TrafficRecord.find_by(id: traffic_record_id)

      if traffic_record.nil?
        render json: { error: 'Traffic record not found' }, status: :not_found
        return
      end

      node = traffic_record.node
      result = RewardEligibilityService.eligible_for_reward?(
        node,
        traffic_record,
        request_source: request_source
      )

      # Cập nhật trạng thái vào record
      traffic_record.update!(
        reward_eligible: result[:eligible],
        eligibility_reason: result[:reason],
        request_source: request_source.to_s
      )

      # Kiểm tra AI scoring
      ai_result = RewardEligibilityService.check_ai_scoring(node)
      traffic_record.update!(
        ai_scored: ai_result[:scored],
        ai_score: ai_result[:score]
      ) if ai_result[:scored]

      # Kiểm tra anomaly
      has_anomaly = RewardEligibilityService.traffic_anomaly?(traffic_record, node)
      traffic_record.update!(has_anomaly: has_anomaly)

      render json: {
        traffic_record_id: traffic_record.id,
        node: node.address,
        eligible: result[:eligible],
        reason: result[:reason],
        request_source: request_source.to_s,
        ai_scoring: {
          scored: ai_result[:scored],
          score: ai_result[:score]
        },
        has_anomaly: has_anomaly,
        performance_threshold_met: RewardEligibilityService.performance_threshold_met?(node),
        is_good_node: RewardEligibilityService.is_good_node?(node)
      }
    end
  end
end
