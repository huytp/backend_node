require 'open3'
require 'base64'

class WireguardService
  class << self
    # Generate WireGuard key pair cho CLIENT (user)
    # LƯU Ý: Server keys (của vpn-node) phải được generate trên vpn-node và gửi lên backend qua heartbeat
    # Method này chỉ dùng để generate keys cho client khi tạo VPN connection
    # YÊU CẦU: WireGuard phải được cài đặt trên server (wg command phải có sẵn)
    def generate_key_pair
      private_key, status1 = Open3.capture2('wg', 'genkey')
      unless status1.success?
        error_msg = "Failed to generate WireGuard private key. Make sure WireGuard is installed: 'wg' command not found."
        Rails.logger.error(error_msg)
        raise error_msg
      end

      private_key = private_key.strip
      public_key, status2 = Open3.capture2('sh', '-c', "echo '#{private_key}' | wg pubkey")
      unless status2.success?
        error_msg = "Failed to generate WireGuard public key. Make sure WireGuard is installed: 'wg pubkey' command failed."
        Rails.logger.error(error_msg)
        raise error_msg
      end

      [private_key.strip, public_key.strip]
    rescue Errno::ENOENT => e
      error_msg = "WireGuard is not installed. Please install WireGuard tools:\n" \
                  "  Ubuntu/Debian: sudo apt-get install wireguard-tools\n" \
                  "  macOS: brew install wireguard-tools\n" \
                  "  CentOS/RHEL: sudo yum install wireguard-tools\n" \
                  "Error: #{e.message}"
      Rails.logger.error(error_msg)
      raise error_msg
    end

    # Tạo WireGuard config cho client
    def create_client_config(private_key:, server_public_key:, server_endpoint:, allowed_ips: '0.0.0.0/0', client_address: nil)
      client_address ||= generate_client_address

      config = <<~CONFIG
        [Interface]
        Address = #{client_address}
        PrivateKey = #{private_key}
        DNS = 8.8.8.8

        [Peer]
        PublicKey = #{server_public_key}
        Endpoint = #{server_endpoint}
        AllowedIPs = #{allowed_ips}
        PersistentKeepalive = 25
      CONFIG

      config.strip
    end

    # Lấy WireGuard info từ VPN node API với retry
    def fetch_node_wireguard_info(node_api_url, retries: 2)
      # Make timeouts configurable via environment variables
      timeout = ENV.fetch('NODE_API_TIMEOUT', '10').to_i
      open_timeout = ENV.fetch('NODE_API_OPEN_TIMEOUT', '5').to_i

      retries.times do |attempt|
        begin
          Rails.logger.debug("Fetching WireGuard info from #{node_api_url}/api/info (attempt #{attempt + 1}/#{retries})")

          response = HTTParty.get(
            "#{node_api_url}/api/info",
            headers: { 'Content-Type' => 'application/json' },
            timeout: timeout,
            open_timeout: open_timeout
          )

          if response.success?
            data = JSON.parse(response.body)
            return {
              public_key: data.dig('wireguard', 'public_key'),
              listen_port: data.dig('wireguard', 'listen_port'),
              endpoint: data.dig('wireguard', 'endpoint')
            }
          else
            Rails.logger.warn("Failed to fetch WireGuard info (attempt #{attempt + 1}/#{retries}): #{response.code} - #{response.body}")
          end
        rescue Net::OpenTimeout, Errno::ETIMEDOUT, Errno::ECONNREFUSED, SocketError => e
          error_type = case e
                       when Net::OpenTimeout, Errno::ETIMEDOUT
                         "Connection timeout"
                       when Errno::ECONNREFUSED
                         "Connection refused"
                       when SocketError
                         "Network error"
                       else
                         "Connection error"
                       end

          Rails.logger.warn("#{error_type} fetching WireGuard info from #{node_api_url} (attempt #{attempt + 1}/#{retries}): #{e.message}")

          if attempt < retries - 1
            sleep_time = (attempt + 1) * 2 # Exponential backoff: 2s, 4s
            Rails.logger.debug("Retrying in #{sleep_time} seconds...")
            sleep(sleep_time)
            next
          else
            raise "Failed to fetch WireGuard info after #{retries} attempts: #{error_type} - #{e.message}"
          end
        rescue => e
          Rails.logger.warn("Error fetching WireGuard info (attempt #{attempt + 1}/#{retries}): #{e.class.name} - #{e.message}")
          if attempt < retries - 1
            sleep((attempt + 1) * 2)
            next
          else
            raise "Failed to fetch WireGuard info after #{retries} attempts: #{e.class.name} - #{e.message}"
          end
        end
      end
    rescue => e
      Rails.logger.error("Error fetching WireGuard info from node: #{e.message}")
      raise
    end

    # Thêm peer vào VPN node với retry
    def add_peer_to_node(node_api_url, peer_public_key, allowed_ips, connection_id, retries: 2)
      timeout = ENV.fetch('NODE_API_TIMEOUT', '10').to_i
      open_timeout = ENV.fetch('NODE_API_OPEN_TIMEOUT', '5').to_i

      retries.times do |attempt|
        begin
          Rails.logger.debug("Adding peer to node #{node_api_url}/api/peers (attempt #{attempt + 1}/#{retries})")

          response = HTTParty.post(
            "#{node_api_url}/api/peers",
            body: {
              public_key: peer_public_key,
              allowed_ips: allowed_ips,
              connection_id: connection_id
            }.to_json,
            headers: { 'Content-Type' => 'application/json' },
            timeout: timeout,
            open_timeout: open_timeout
          )

          if response.success?
            return true
          else
            Rails.logger.warn("Failed to add peer (attempt #{attempt + 1}/#{retries}): #{response.code} - #{response.body}")
          end
        rescue Net::OpenTimeout, Errno::ETIMEDOUT, Errno::ECONNREFUSED, SocketError => e
          error_type = case e
                       when Net::OpenTimeout, Errno::ETIMEDOUT
                         "Connection timeout"
                       when Errno::ECONNREFUSED
                         "Connection refused"
                       when SocketError
                         "Network error"
                       else
                         "Connection error"
                       end

          Rails.logger.warn("#{error_type} adding peer to #{node_api_url} (attempt #{attempt + 1}/#{retries}): #{e.message}")

          if attempt < retries - 1
            sleep_time = (attempt + 1) * 2
            Rails.logger.debug("Retrying in #{sleep_time} seconds...")
            sleep(sleep_time)
            next
          else
            raise "Failed to add peer to node after #{retries} attempts: #{error_type} - #{e.message}"
          end
        rescue => e
          Rails.logger.warn("Error adding peer (attempt #{attempt + 1}/#{retries}): #{e.class.name} - #{e.message}")
          if attempt < retries - 1
            sleep((attempt + 1) * 2)
            next
          else
            raise "Failed to add peer to node after #{retries} attempts: #{e.class.name} - #{e.message}"
          end
        end
      end
    rescue => e
      Rails.logger.error("Error adding peer to node: #{e.message}")
      raise
    end

    # Xóa peer khỏi VPN node
    def remove_peer_from_node(node_api_url, connection_id)
      timeout = ENV.fetch('NODE_API_TIMEOUT', '10').to_i
      open_timeout = ENV.fetch('NODE_API_OPEN_TIMEOUT', '5').to_i

      begin
        response = HTTParty.delete(
          "#{node_api_url}/api/peers/#{connection_id}",
          headers: { 'Content-Type' => 'application/json' },
          timeout: timeout,
          open_timeout: open_timeout
        )

        unless response.success?
          Rails.logger.warn("Failed to remove peer from node: #{response.code} - #{response.body}")
          # Không raise để không block disconnect flow
        end

        true
      rescue Net::OpenTimeout, Errno::ETIMEDOUT, Errno::ECONNREFUSED, SocketError => e
        Rails.logger.warn("Connection error removing peer from node: #{e.class.name} - #{e.message}")
        # Không raise để không block disconnect flow
        true
      rescue => e
        Rails.logger.error("Error removing peer from node: #{e.class.name} - #{e.message}")
        # Không raise để không block disconnect flow
        true
      end
    end

    private

    def generate_client_address
      # Generate random IP trong range 10.0.0.0/24
      # Tránh conflict với server IPs (thường là 10.0.0.1-10.0.0.10)
      client_ip = rand(11..254)
      "10.0.0.#{client_ip}/24"
    end
  end
end

