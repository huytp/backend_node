require 'eth'
require 'json'

class TrafficVerifier
  def self.verify(record_data, signature, node_address)
    # Reconstruct message that was signed
    message = {
      node: record_data[:node] || record_data['node'],
      session_id: record_data[:session_id] || record_data['session_id'],
      traffic_mb: record_data[:traffic_mb] || record_data['traffic_mb'],
      epoch_id: record_data[:epoch_id] || record_data['epoch_id'],
      timestamp: record_data[:timestamp] || record_data['timestamp']
    }.to_json

    # Verify signature
    begin
      # Remove 0x prefix if present
      sig = signature.to_s
      sig = sig[2..-1] if sig.start_with?('0x')

      # Verify using Ethereum signature verification
      # Note: This is a simplified version. In production, use proper ECDSA verification
      # For now, we'll verify that signature exists and node address matches
      if sig.length < 130 # Ethereum signature should be 65 bytes = 130 hex chars
        return false
      end

      # Verify node address matches
      record_node = (record_data[:node] || record_data['node']).to_s.downcase
      expected_node = node_address.to_s.downcase

      return false unless record_node == expected_node

      # TODO: Implement full ECDSA signature verification
      # For MVP, we'll do basic checks
      true
    rescue => e
      Rails.logger.error("Traffic verification error: #{e.message}")
      false
    end
  end

  def self.verify_batch(records)
    results = []

    records.each do |record|
      verified = verify(
        record,
        record[:signature] || record['signature'],
        record[:node] || record['node']
      )
      results << { record: record, verified: verified }
    end

    results
  end
end

