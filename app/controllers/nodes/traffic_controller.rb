module Nodes
  class TrafficController < ApplicationController
    # POST /nodes/traffic
    # Node gửi traffic record lên backend
    def create
      node_address = params[:node] || request.headers['X-Node-Address']
      traffic_data = params.permit(:session_id, :traffic_mb, :epoch_id, :timestamp, :signature)

      if node_address.blank?
        render json: { error: 'Node address is required' }, status: :bad_request
        return
      end

      # Tìm node
      node = ::Node.find_by(address: node_address)
      if node.nil?
        render json: { error: 'Node not found' }, status: :not_found
        return
      end

      # Verify signature
      record_data = {
        node: node_address,
        session_id: traffic_data[:session_id],
        traffic_mb: traffic_data[:traffic_mb],
        epoch_id: traffic_data[:epoch_id],
        timestamp: traffic_data[:timestamp]
      }

      unless TrafficVerifier.verify(record_data, traffic_data[:signature], node_address)
        render json: { error: 'Invalid signature' }, status: :unauthorized
        return
      end

      # Tìm VPN connection từ session_id
      vpn_connection = VpnConnection.find_by(connection_id: traffic_data[:session_id])

      # Tạo traffic record
      # Note: Callback after_create sẽ tự động kiểm tra AI scoring và eligibility
      traffic_record = TrafficRecord.create!(
        node: node,
        vpn_connection: vpn_connection,
        epoch_id: traffic_data[:epoch_id],
        traffic_mb: traffic_data[:traffic_mb].to_f,
        signature: traffic_data[:signature]
      )

      Rails.logger.info(
        "Traffic record created - ID: #{traffic_record.id}, " \
        "Node: #{node_address}, Traffic: #{traffic_data[:traffic_mb]} MB, " \
        "Session: #{traffic_data[:session_id]}"
      )

      render json: {
        id: traffic_record.id,
        node: node_address,
        session_id: traffic_data[:session_id],
        traffic_mb: traffic_record.traffic_mb,
        epoch_id: traffic_record.epoch_id,
        reward_eligible: traffic_record.reward_eligible,
        eligibility_reason: traffic_record.eligibility_reason,
        ai_scored: traffic_record.ai_scored,
        ai_score: traffic_record.ai_score,
        created_at: traffic_record.created_at
      }, status: :created
    rescue => e
      Rails.logger.error("Failed to create traffic record: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /nodes/traffic/batch
    # Node gửi nhiều traffic records cùng lúc
    def batch_create
      node_address = params[:node] || request.headers['X-Node-Address']
      records_data = params[:records] || []

      if node_address.blank?
        render json: { error: 'Node address is required' }, status: :bad_request
        return
      end

      if records_data.empty?
        render json: { error: 'Records array is required' }, status: :bad_request
        return
      end

      # Tìm node
      node = ::Node.find_by(address: node_address)
      if node.nil?
        render json: { error: 'Node not found' }, status: :not_found
        return
      end

      results = []
      errors = []

      records_data.each do |record_data|
        begin
          # Verify signature
          record_for_verify = {
            node: node_address,
            session_id: record_data[:session_id] || record_data['session_id'],
            traffic_mb: record_data[:traffic_mb] || record_data['traffic_mb'],
            epoch_id: record_data[:epoch_id] || record_data['epoch_id'],
            timestamp: record_data[:timestamp] || record_data['timestamp']
          }

          signature = record_data[:signature] || record_data['signature']

          unless TrafficVerifier.verify(record_for_verify, signature, node_address)
            errors << { record: record_data, error: 'Invalid signature' }
            next
          end

          # Tìm VPN connection
          session_id = record_data[:session_id] || record_data['session_id']
          vpn_connection = VpnConnection.find_by(connection_id: session_id)

          # Tạo traffic record
          traffic_record = TrafficRecord.create!(
            node: node,
            vpn_connection: vpn_connection,
            epoch_id: record_data[:epoch_id] || record_data['epoch_id'],
            traffic_mb: (record_data[:traffic_mb] || record_data['traffic_mb']).to_f,
            signature: signature
          )

          results << {
            id: traffic_record.id,
            session_id: session_id,
            traffic_mb: traffic_record.traffic_mb,
            reward_eligible: traffic_record.reward_eligible,
            ai_scored: traffic_record.ai_scored
          }
        rescue => e
          errors << { record: record_data, error: e.message }
          Rails.logger.error("Failed to create traffic record in batch: #{e.message}")
        end
      end

      render json: {
        created: results.length,
        failed: errors.length,
        results: results,
        errors: errors
      }, status: :ok
    end
  end
end

