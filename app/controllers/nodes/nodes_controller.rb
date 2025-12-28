module Nodes
  class NodesController < ApplicationController
    # POST /nodes/heartbeat
    def heartbeat
      node_address = params[:node]
      heartbeat_data = params.permit(:latency, :loss, :bandwidth, :uptime, :signature)

      # Tìm hoặc tạo node (sử dụng ::Node để reference đến model class, không phải module)
      node = ::Node.find_or_create_by(address: node_address) do |n|
        n.status = :active
      end

      # Tạo heartbeat record
      heartbeat = node.heartbeats.create!(
        latency: heartbeat_data[:latency],
        loss: heartbeat_data[:loss],
        bandwidth: heartbeat_data[:bandwidth],
        uptime: heartbeat_data[:uptime],
        signature: heartbeat_data[:signature]
      )

      # Cập nhật node info
      node.update_from_heartbeat(heartbeat_data)

      # Cập nhật node_api_url nếu có
      if params[:node_api_url].present?
        node.update!(node_api_url: params[:node_api_url])
      end

      # Gửi metrics đến AI Routing Engine
      send_to_ai_routing(node, heartbeat_data)

      # Detect anomaly và update reputation
      update_reputation(node, heartbeat_data)

      render json: {
        status: 'ok',
        node: node.address,
        heartbeat_id: heartbeat.id
      }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # GET /nodes/status/:address
    def status
      node = ::Node.find_by(address: params[:address])

      if node.nil?
        render json: { error: 'Node not found' }, status: :not_found
        return
      end

      render json: {
        address: node.address,
        status: node.status,
        latency: node.latency,
        loss: node.loss,
        bandwidth: node.bandwidth,
        uptime: node.uptime,
        reputation_score: node.reputation_score,
        last_heartbeat: node.last_heartbeat_at
      }
    end

    # GET /nodes/status
    def index
      nodes = ::Node.active_nodes

      render json: nodes.map { |node|
        {
          address: node.address,
          status: node.status,
          latency: node.latency,
          loss: node.loss,
          bandwidth: node.bandwidth,
          uptime: node.uptime,
          reputation_score: node.reputation_score
        }
      }
    end

    private

    def send_to_ai_routing(node, heartbeat_data)
      # Gửi metrics đến AI Routing Engine
      ai_routing_url = ENV['AI_ROUTING_URL'] || 'http://localhost:8000'

      payload = {
        node: node.address,
        latency: heartbeat_data[:latency],
        loss: heartbeat_data[:loss],
        jitter: 0, # TODO: tính từ historical data
        uptime: heartbeat_data[:uptime],
        bandwidth: heartbeat_data[:bandwidth]
      }

      HTTParty.post(
        "#{ai_routing_url}/node/metrics",
        body: payload.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    rescue => e
      Rails.logger.error("Failed to send to AI Routing: #{e.message}")
    end

    def update_reputation(node, heartbeat_data)
      # Gọi AI Routing để detect anomaly
      ai_routing_url = ENV['AI_ROUTING_URL'] || 'http://localhost:8000'

      payload = {
        node: node.address,
        latency: heartbeat_data[:latency],
        loss: heartbeat_data[:loss],
        jitter: 0,
        uptime: heartbeat_data[:uptime],
        bandwidth: heartbeat_data[:bandwidth]
      }

      response = HTTParty.post(
        "#{ai_routing_url}/reputation/update",
        body: payload.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      if response.success?
        reputation_data = JSON.parse(response.body)
        node.update!(reputation_score: reputation_data['score'])
      end
    rescue => e
      Rails.logger.error("Failed to update reputation: #{e.message}")
    end
  end
end

