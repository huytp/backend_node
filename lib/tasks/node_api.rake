namespace :node do
  desc "Test connection to node API"
  task :test_api, [:node_address] => :environment do |t, args|
    node_address = args[:node_address]

    unless node_address
      puts "Usage: rails node:test_api[NODE_ADDRESS]"
      puts "Example: rails node:test_api[0x569466705D52084149ed610ff3D95Ea4318876cD]"
      exit 1
    end

    node = Node.find_by(address: node_address)

    if node.nil?
      puts "✗ Node not found: #{node_address}"
      exit 1
    end

    puts "Testing connection to node: #{node_address}"
    puts "=" * 60

    # Get API URL
    controller = Vpn::ConnectionsController.new
    api_url = controller.send(:get_node_api_url, node)

    if api_url.nil?
      puts "✗ No API URL available for node"
      puts "\nPossible solutions:"
      puts "1. Node should send node_api_url in heartbeat"
      puts "2. Set node_api_url manually:"
      puts "   rails node:set_api_url[#{node_address},http://IP:PORT]"
      exit 1
    end

    puts "API URL: #{api_url}"
    puts "\nTesting connection..."

    begin
      require 'httparty'
      response = HTTParty.get(
        "#{api_url}/api/health",
        timeout: 5,
        open_timeout: 3
      )

      if response.success?
        puts "✓ Connection successful!"
        puts "Response: #{response.body}"
      else
        puts "✗ Connection failed: HTTP #{response.code}"
        puts "Response: #{response.body}"
      end
    rescue Net::OpenTimeout, Errno::ETIMEDOUT => e
      puts "✗ Connection timeout"
      puts "Error: #{e.message}"
      puts "\nPossible issues:"
      puts "1. Port forwarding not configured on router"
      puts "2. Firewall blocking connection"
      puts "3. Node API not running"
      puts "4. Wrong IP/port"
    rescue Errno::ECONNREFUSED => e
      puts "✗ Connection refused"
      puts "Error: #{e.message}"
      puts "\nPossible issues:"
      puts "1. Node API not running"
      puts "2. Wrong port"
      puts "3. Service not listening on that IP"
    rescue SocketError => e
      puts "✗ Network error"
      puts "Error: #{e.message}"
      puts "\nPossible issues:"
      puts "1. Invalid IP address"
      puts "2. DNS resolution failed"
    rescue => e
      puts "✗ Error: #{e.class.name} - #{e.message}"
    end
  end

  desc "Set node API URL manually"
  task :set_api_url, [:node_address, :api_url] => :environment do |t, args|
    node_address = args[:node_address]
    api_url = args[:api_url]

    unless node_address && api_url
      puts "Usage: rails node:set_api_url[NODE_ADDRESS,API_URL]"
      puts "Example: rails node:set_api_url[0x569...,http://183.80.151.69:51820]"
      exit 1
    end

    node = Node.find_by(address: node_address)

    if node.nil?
      puts "✗ Node not found: #{node_address}"
      exit 1
    end

    # Validate URL format
    unless api_url.match?(/^https?:\/\//)
      puts "✗ Invalid URL format. Must start with http:// or https://"
      exit 1
    end

    node.update!(node_api_url: api_url)
    puts "✓ Updated node_api_url for #{node_address}"
    puts "  New URL: #{api_url}"

    # Test connection
    puts "\nTesting connection..."
    begin
      require 'httparty'
      response = HTTParty.get(
        "#{api_url}/api/health",
        timeout: 5,
        open_timeout: 3
      )

      if response.success?
        puts "✓ Connection test successful!"
      else
        puts "⚠ Connection test failed: HTTP #{response.code}"
      end
    rescue => e
      puts "⚠ Connection test failed: #{e.message}"
      puts "  (URL saved but connection test failed)"
    end
  end

  desc "List all nodes with API URL status"
  task list_api: :environment do
    nodes = Node.all

    if nodes.empty?
      puts "No nodes found"
      exit 0
    end

    puts "Node API URL Status"
    puts "=" * 80
    printf "%-42s %-30s %-10s\n", "Address", "API URL", "Status"
    puts "-" * 80

    nodes.each do |node|
      api_url = node.node_api_url
      status = if api_url.present?
        # Test connection
        begin
          require 'httparty'
          response = HTTParty.get(
            "#{api_url}/api/health",
            timeout: 3,
            open_timeout: 2
          )
          response.success? ? "✓ OK" : "✗ HTTP #{response.code}"
        rescue => e
          "✗ Error"
        end
      else
        "Not set"
      end

      printf "%-42s %-30s %-10s\n",
        node.address[0..40],
        (api_url || "N/A")[0..28],
        status
    end
  end

  desc "Update node API URL from wireguard_endpoint"
  task :update_api_from_endpoint, [:node_address] => :environment do |t, args|
    node_address = args[:node_address]

    unless node_address
      puts "Usage: rails node:update_api_from_endpoint[NODE_ADDRESS]"
      puts "Example: rails node:update_api_from_endpoint[0x569...]"
      exit 1
    end

    node = Node.find_by(address: node_address)

    if node.nil?
      puts "✗ Node not found: #{node_address}"
      exit 1
    end

    unless node.wireguard_endpoint.present?
      puts "✗ Node has no wireguard_endpoint"
      exit 1
    end

    # Extract IP from endpoint
    ip = node.wireguard_endpoint.split(':').first
    api_port = ENV['NODE_API_PORT'] || '51820'
    api_url = "http://#{ip}:#{api_port}"

    node.update!(node_api_url: api_url)
    puts "✓ Updated node_api_url from wireguard_endpoint"
    puts "  Endpoint: #{node.wireguard_endpoint}"
    puts "  API URL: #{api_url}"
  end
end


