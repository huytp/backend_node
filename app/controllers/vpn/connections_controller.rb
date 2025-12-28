module Vpn
  class ConnectionsController < ApplicationController
    # POST /vpn/connect
    def connect
      user_address = request.remote_ip
      puts "user_address: #{user_address}"
      preferred_nodes = params[:preferred_nodes] || []

      Rails.logger.info("VPN Connect request - user_address: #{user_address}, preferred_nodes: #{preferred_nodes.inspect}")

      # Gọi AI Routing để chọn route
      route = select_route(preferred_nodes)

      # Fallback: Nếu AI routing không có route, chọn từ database
      if route.nil?
        Rails.logger.info("AI Routing returned no route, falling back to database selection")
        route = select_route_from_database(preferred_nodes)
      else
        Rails.logger.info("Route selected from AI Routing: entry=#{route['entry']}, exit=#{route['exit']}, score=#{route['score']}")
      end

      if route.nil?
        Rails.logger.warn("No available route found for user: #{user_address}")
        render json: { error: 'No available route. Please ensure nodes are registered and AI routing engine is running.' }, status: :service_unavailable
        return
      end

      # Tìm nodes
      entry_node = Node.find_by(address: route['entry'])
      exit_node = Node.find_by(address: route['exit'])

      if entry_node.nil? || exit_node.nil?
        Rails.logger.error("Nodes not found - entry: #{route['entry']}, exit: #{route['exit']}")
        render json: { error: 'Nodes not found' }, status: :not_found
        return
      end

      # Tạo connection
      connection = VpnConnection.create!(
        user_address: user_address,
        entry_node: entry_node,
        exit_node: exit_node,
        route_score: route['score'],
        status: :connected
      )

      Rails.logger.info("VPN Connection created successfully - connection_id: #{connection.connection_id}, user: #{user_address}, entry: #{entry_node.address}, exit: #{exit_node.address}")

      # Tạo WireGuard config cho mobile app
      wireguard_config = nil
      begin
        wireguard_config = create_wireguard_config(connection, entry_node)
      rescue => e
        Rails.logger.error("Failed to create WireGuard config: #{e.message}")
        # Vẫn trả về connection info nếu WireGuard config fail
      end

      response_data = {
        connection_id: connection.connection_id,
        entry_node: entry_node.address,
        exit_node: exit_node.address,
        route_score: route['score'],
        status: 'connected'
      }

      # Thêm WireGuard config nếu có
      if wireguard_config
        response_data[:wireguard_config] = wireguard_config[:config]
        response_data[:client_private_key] = wireguard_config[:client_private_key]
      end

      render json: response_data
    rescue => e
      Rails.logger.error("VPN Connect error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # POST /vpn/disconnect
    def disconnect
      connection_id = params[:connection_id]

      Rails.logger.info("VPN Disconnect request - connection_id: #{connection_id}")

      connection = VpnConnection.find_by(connection_id: connection_id)

      if connection.nil?
        Rails.logger.warn("VPN Connection not found for disconnect - connection_id: #{connection_id}")
        render json: { error: 'Connection not found' }, status: :not_found
        return
      end

      connection.update!(status: :disconnected)
      connection.check_reward_eligibility_on_disconnect

      # Xóa peer khỏi VPN node
      begin
        remove_peer_from_node(connection)
      rescue => e
        Rails.logger.error("Failed to remove peer from node: #{e.message}")
        # Không block disconnect flow nếu remove peer fail
      end

      Rails.logger.info("VPN Connection disconnected - connection_id: #{connection_id}, user: #{connection.user_address}")

      render json: {
        connection_id: connection_id,
        status: 'disconnected'
      }
    end

    # GET /vpn/status/:connection_id
    def status
      connection_id = params[:connection_id]
      Rails.logger.info("VPN Status request - connection_id: #{connection_id}")

      connection = VpnConnection.find_by(connection_id: connection_id)

      if connection.nil?
        Rails.logger.warn("VPN Connection not found for status check - connection_id: #{connection_id}")
        render json: { error: 'Connection not found' }, status: :not_found
        return
      end

      Rails.logger.debug("VPN Connection status - connection_id: #{connection.connection_id}, status: #{connection.status}, user: #{connection.user_address}")

      # Tính tổng traffic và tốc độ trung bình
      total_traffic_mb = connection.traffic_records.sum(:traffic_mb)
      connection_duration = (Time.current - connection.created_at).to_i # seconds
      avg_speed_mbps = connection_duration > 0 ? (total_traffic_mb * 8 / connection_duration) : 0

      # Lấy traffic gần nhất để tính tốc độ hiện tại
      recent_traffic = connection.traffic_records
        .where('created_at > ?', 30.seconds.ago)
        .sum(:traffic_mb)
      current_speed_mbps = recent_traffic > 0 ? (recent_traffic * 8 / 30) : 0

      render json: {
        connection_id: connection.connection_id,
        user_address: connection.user_address,
        entry_node: connection.entry_node.address,
        exit_node: connection.exit_node.address,
        route_score: connection.route_score,
        status: connection.status,
        created_at: connection.created_at,
        stats: {
          total_traffic_mb: total_traffic_mb.round(2),
          avg_speed_mbps: avg_speed_mbps.round(2),
          current_speed_mbps: current_speed_mbps.round(2),
          connection_duration: connection_duration
        }
      }
    end

    # GET /vpn/connections/active
    # Lấy active connections mà node này tham gia (entry hoặc exit)
    def active
      node_address = params[:node]

      if node_address.blank?
        render json: { error: 'node parameter is required' }, status: :bad_request
        return
      end

      node = Node.find_by(address: node_address)

      if node.nil?
        render json: { error: 'Node not found' }, status: :not_found
        return
      end

      # Lấy connections mà node này là entry hoặc exit và status là connected
      connections = VpnConnection.where(status: 'connected')
        .where('entry_node_id = ? OR exit_node_id = ?', node.id, node.id)
        .includes(:entry_node, :exit_node)

      render json: {
        node: node_address,
        connections: connections.map do |conn|
          {
            connection_id: conn.connection_id,
            user_address: conn.user_address,
            entry_node: conn.entry_node.address,
            exit_node: conn.exit_node.address,
            route_score: conn.route_score,
            status: conn.status,
            created_at: conn.created_at
          }
        end
      }
    end

    private

    def create_wireguard_config(connection, entry_node)
      # Lấy hoặc fetch WireGuard info từ entry node
      node_api_url = get_node_api_url(entry_node)

      wg_info = nil
      cache_age_hours = nil
      max_cache_age_hours = ENV.fetch('WIREGUARD_CACHE_MAX_AGE_HOURS', '24').to_i

      # Thử lấy từ database trước (nếu đã có)
      if entry_node.wireguard_public_key.present? && entry_node.wireguard_endpoint.present?
        # Check cache age if updated_at is available
        if entry_node.updated_at.present?
          cache_age_hours = ((Time.current - entry_node.updated_at) / 1.hour).round(2)
          if cache_age_hours <= max_cache_age_hours
            Rails.logger.info("Using cached WireGuard info from database for node: #{entry_node.address} (cache age: #{cache_age_hours}h)")
            wg_info = {
              public_key: entry_node.wireguard_public_key,
              listen_port: entry_node.wireguard_listen_port || 51820,
              endpoint: entry_node.wireguard_endpoint
            }
          else
            Rails.logger.warn("Cached WireGuard info for node #{entry_node.address} is too old (#{cache_age_hours}h), will try to refresh")
          end
        else
          # No updated_at, use cached info anyway
          Rails.logger.info("Using cached WireGuard info from database for node: #{entry_node.address} (no timestamp available)")
          wg_info = {
            public_key: entry_node.wireguard_public_key,
            listen_port: entry_node.wireguard_listen_port || 51820,
            endpoint: entry_node.wireguard_endpoint
          }
        end
      end

      # Nếu không có trong DB hoặc cache quá cũ, thử fetch từ API
      if wg_info.nil? && node_api_url
        begin
          Rails.logger.info("Fetching WireGuard info from node API: #{node_api_url}")
          wg_info = WireguardService.fetch_node_wireguard_info(node_api_url)

          # Lưu vào database để dùng lần sau
          if wg_info[:public_key] && wg_info[:endpoint]
            entry_node.update!(
              wireguard_public_key: wg_info[:public_key],
              wireguard_listen_port: wg_info[:listen_port],
              wireguard_endpoint: wg_info[:endpoint],
              node_api_url: node_api_url
            )
            Rails.logger.info("Saved WireGuard info to database for node: #{entry_node.address}")
          end
        rescue => e
          Rails.logger.error("Failed to fetch WireGuard info from API: #{e.class.name} - #{e.message}")

          # Fallback: Use stale cache if available, even if old
          if entry_node.wireguard_public_key.present? && entry_node.wireguard_endpoint.present?
            Rails.logger.warn("Using stale cached WireGuard info for node #{entry_node.address} (API unavailable)")
            wg_info = {
              public_key: entry_node.wireguard_public_key,
              listen_port: entry_node.wireguard_listen_port || 51820,
              endpoint: entry_node.wireguard_endpoint
            }
          else
            # No cached info available, raise error
            raise "Cannot create WireGuard config: Node API unavailable (#{node_api_url}) and no cached info. Error: #{e.message}"
          end
        end
      elsif wg_info.nil? && node_api_url.nil?
        Rails.logger.warn("No node API URL available for node: #{entry_node.address}")
      end

      # Nếu vẫn không có info, raise error
      unless wg_info && wg_info[:public_key] && wg_info[:endpoint]
        error_msg = "WireGuard info not available for node: #{entry_node.address}."
        error_msg += " Node API URL: #{node_api_url || 'not configured'}"
        error_msg += " Cached info: #{entry_node.wireguard_public_key.present? ? 'present but invalid' : 'not available'}"
        error_msg += ". Please ensure node API is running or node has valid cached WireGuard info."
        raise error_msg
      end

      # Generate client key pair
      client_private_key, client_public_key = WireguardService.generate_key_pair

      # Tạo WireGuard config cho client
      client_config = WireguardService.create_client_config(
        private_key: client_private_key,
        server_public_key: wg_info[:public_key],
        server_endpoint: wg_info[:endpoint]
      )

      # Thêm peer vào entry node (nếu có API URL)
      if node_api_url
        begin
          WireguardService.add_peer_to_node(
            node_api_url,
            client_public_key,
            '0.0.0.0/0',
            connection.connection_id
          )
          Rails.logger.info("Successfully added peer to node: #{entry_node.address}")
        rescue => e
          Rails.logger.warn("Failed to add peer to node (config still created): #{e.message}")
          # Không raise để vẫn trả về config cho user
        end
      else
        Rails.logger.warn("Node API URL not available, skipping peer addition. User will need to manually add peer on node.")
      end

      {
        config: client_config,
        client_private_key: client_private_key
      }
    end

    def remove_peer_from_node(connection)
      entry_node = connection.entry_node
      node_api_url = get_node_api_url(entry_node)

      return unless node_api_url

      WireguardService.remove_peer_from_node(node_api_url, connection.connection_id)
    end

    def get_node_api_url(node)
      # Priority 1: Lấy từ node.node_api_url (được node gửi trong heartbeat)
      if node.node_api_url.present?
        Rails.logger.debug("Using node_api_url from database: #{node.node_api_url}")
        return node.node_api_url
      end

      # Priority 2: Construct từ wireguard_endpoint với port API riêng
      if node.wireguard_endpoint.present?
        # Extract IP từ endpoint (format: IP:PORT)
        ip = node.wireguard_endpoint.split(':').first
        # Node API port có thể khác với WireGuard port
        api_port = ENV['NODE_API_PORT'] || ENV['NODE_API_DEFAULT_PORT'] || '51820'
        api_url = "http://#{ip}:#{api_port}"
        Rails.logger.debug("Constructed node_api_url from endpoint: #{api_url}")
        return api_url
      end

      # Priority 3: Thử detect internal IP nếu backend và node cùng mạng
      # (Chỉ khi không có public IP)
      internal_ip = detect_internal_ip_for_node(node)
      if internal_ip
        api_port = ENV['NODE_API_PORT'] || '51820'
        api_url = "http://#{internal_ip}:#{api_port}"
        Rails.logger.debug("Using internal IP for node: #{api_url}")
        return api_url
      end

      Rails.logger.warn("No node API URL available for node: #{node.address}")
      nil
    end

    def detect_internal_ip_for_node(node)
      # Nếu node có wireguard_endpoint, extract IP từ đó
      # Có thể là internal IP nếu backend và node cùng mạng
      if node.wireguard_endpoint.present?
        ip = node.wireguard_endpoint.split(':').first
        # Kiểm tra xem có phải private IP không
        if ip.match?(/^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)/)
          return ip
        end
      end
      nil
    end

    def select_route(preferred_nodes)
      ai_routing_url = ENV['AI_ROUTING_URL'] || 'http://localhost:8000'

      payload = {
        time_bucket: Time.current.hour,
        available_nodes: preferred_nodes.empty? ? nil : preferred_nodes
      }

      Rails.logger.debug("Calling AI Routing service at #{ai_routing_url}/route/select with payload: #{payload.inspect}")

      response = HTTParty.post(
        "#{ai_routing_url}/route/select",
        body: payload.to_json,
        headers: { 'Content-Type' => 'application/json' },
        timeout: 5
      )

      unless response.success?
        Rails.logger.warn("AI Routing service returned error - status: #{response.code}, body: #{response.body}")
        return nil
      end

      route = JSON.parse(response.body)
      Rails.logger.debug("AI Routing service response: #{route.inspect}")
      route
    rescue => e
      Rails.logger.error("Failed to select route from AI Routing: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      nil
    end

    def select_route_from_database(preferred_nodes)
      # Fallback: Chọn route từ database nodes
      Rails.logger.debug("Selecting route from database - preferred_nodes: #{preferred_nodes.inspect}")

      available_nodes = if preferred_nodes.empty?
        Node.active_nodes.pluck(:address)
      else
        Node.active_nodes.where(address: preferred_nodes).pluck(:address)
      end

      Rails.logger.debug("Available nodes from database: #{available_nodes.inspect} (#{available_nodes.length} nodes)")

      if available_nodes.length < 2
        Rails.logger.warn("Not enough available nodes for route selection (need 2, got #{available_nodes.length})")
        return nil
      end

      # Chọn 2 nodes tốt nhất dựa trên quality score
      nodes_with_scores = Node.active_nodes.where(address: available_nodes).map do |node|
        {
          address: node.address,
          score: node.calculate_quality_score || 0.5
        }
      end.sort_by { |n| -n[:score] }

      entry = nodes_with_scores[0][:address]
      exit_node = nodes_with_scores.length > 1 ? nodes_with_scores[1][:address] : nodes_with_scores[0][:address]
      score = (nodes_with_scores[0][:score] + nodes_with_scores[1][:score]) / 200.0 # Normalize to 0-1

      route = {
        'entry' => entry,
        'exit' => exit_node,
        'score' => [score, 1.0].min
      }

      Rails.logger.info("Route selected from database: entry=#{entry}, exit=#{exit_node}, score=#{route['score']}")

      route
    rescue => e
      Rails.logger.error("Failed to select route from database: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      nil
    end
  end
end

