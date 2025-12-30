require 'digest'
require 'eth'
require_relative 'rpc_client_service'

class SettlementService
  def self.settle_epoch(epoch_id)
    epoch = Epoch.find_by(epoch_id: epoch_id)
    return false if epoch.nil? || epoch.committed?

    epoch.update!(status: :processing)

    begin
      # Tính rewards - CHỈ tính cho các traffic records đủ điều kiện
      rewards_data = epoch.calculate_rewards_with_eligibility

      # Kiểm tra nếu không có rewards nào
      if rewards_data.empty?
        Rails.logger.info("No eligible rewards for epoch #{epoch_id}")
        epoch.update!(
          status: :committed,
          total_traffic: 0,
          node_count: 0
        )
        return true
      end

      # Build Merkle tree
      leaves_data = rewards_data.map do |reward|
        {
          node: reward[:node],
          amount: reward[:reward_amount]
        }
      end

      merkle_root = MerkleTreeService.build_tree(leaves_data)

      # Kiểm tra merkle_root không nil
      if merkle_root.nil?
        Rails.logger.error("Failed to build merkle tree for epoch #{epoch_id}")
        epoch.update!(status: :pending)
        return false
      end

      # Generate leaves hashes for proof
      leaves_hashes = leaves_data.map do |leaf|
        node_address = leaf[:node].is_a?(Node) ? leaf[:node].address : leaf[:node]
        Digest::SHA256.hexdigest("#{node_address}#{leaf[:amount]}")
      end

      # Lưu rewards với merkle proof - CHỈ cho các node đủ điều kiện
      leaves_data.each_with_index do |leaf, index|
        proof = MerkleTreeService.generate_proof(leaves_hashes, index)

        Reward.create!(
          node: leaf[:node],
          epoch: epoch,
          amount: leaf[:amount],
          merkle_proof: proof.to_json
        )
      end

      # Commit on-chain
      commit_to_blockchain(epoch_id, merkle_root)

      # Update epoch
      epoch.update!(
        merkle_root: merkle_root,
        status: :committed,
        total_traffic: rewards_data.sum { |r| r[:traffic_mb] },
        node_count: rewards_data.length
      )

      true
    rescue => e
      Rails.logger.error("Settlement failed for epoch #{epoch_id}: #{e.message}")
      epoch.update!(status: :pending)
      false
    end
  end

  private

  def self.commit_to_blockchain(epoch_id, merkle_root)
    return unless ENV['REWARD_CONTRACT_ADDRESS'] && ENV['SETTLEMENT_PRIVATE_KEY']

    Rails.logger.info("Committing epoch #{epoch_id} with root #{merkle_root} to blockchain")

    begin
      # Initialize RPC client
      rpc = RpcClientService.new

      # Initialize signer
      private_key = ENV['SETTLEMENT_PRIVATE_KEY']
      private_key = private_key[2..-1] if private_key.start_with?('0x')
      key = Eth::Key.new(priv: private_key)
      contract_address = ENV['REWARD_CONTRACT_ADDRESS']

      # Function selector for commitEpoch(uint256,bytes32)
      # Calculated: keccak256("commitEpoch(uint256,bytes32)")[0:4] = 0x...
      function_selector = "0x" + calculate_commit_epoch_selector

      # Encode parameters
      encoded_epoch = encode_uint256(epoch_id)
      encoded_root = encode_bytes32(merkle_root)

      # Build transaction data
      function_data = "#{function_selector}#{encoded_epoch}#{encoded_root}"

      # Get transaction parameters
      nonce_hex = rpc.eth_get_transaction_count(key.address.to_s, 'latest')
      nonce = rpc.hex_to_int(nonce_hex)

      gas_price_hex = rpc.eth_gas_price
      gas_price = rpc.hex_to_int(gas_price_hex)
      gas_price = 30_000_000_000 if gas_price == 0 # Default 30 gwei

      # Estimate gas
      begin
        gas_limit_hex = rpc.eth_estimate_gas({
          from: key.address.to_s,
          to: contract_address,
          data: function_data
        })
        gas_limit = rpc.hex_to_int(gas_limit_hex)
        gas_limit = (gas_limit * 1.2).to_i # Add 20% buffer
      rescue => e
        Rails.logger.warn("Gas estimation failed: #{e.message}, using default")
        gas_limit = 200_000
      end

      # Build transaction
      transaction = Eth::Tx.new(
        chain_id: 80_002, # Polygon Amoy
        nonce: nonce,
        gas_price: gas_price,
        gas_limit: gas_limit,
        to: contract_address,
        data: function_data[2..-1] # Remove 0x prefix
      )

      # Sign transaction
      transaction.sign(key)
      signed_tx = transaction.hex
      signed_tx = "0x#{signed_tx}" unless signed_tx.start_with?('0x')

      # Send transaction
      tx_hash = rpc.eth_send_raw_transaction(signed_tx)
      Rails.logger.info("Transaction sent: #{tx_hash}")
      Rails.logger.info("Explorer: https://amoy.polygonscan.com/tx/#{tx_hash}")

      # Wait for receipt (optional, can be async)
      receipt = wait_for_receipt(rpc, tx_hash, 60)
      if receipt && receipt['status'] == '0x1'
        Rails.logger.info("✅ Epoch #{epoch_id} committed successfully on blockchain")
        Rails.logger.info("Block: #{receipt['blockNumber']}, Gas used: #{receipt['gasUsed'].to_i(16)}")
        return true
      else
        Rails.logger.error("❌ Transaction failed for epoch #{epoch_id}")
        return false
      end
    rescue => e
      Rails.logger.error("Failed to commit epoch #{epoch_id} to blockchain: #{e.message}")
      Rails.logger.error(e.backtrace.first(5))
      false
    end
  end

  # Function selector for commitEpoch(uint256,bytes32)
  # Calculated with: ethers.keccak256(ethers.toUtf8Bytes("commitEpoch(uint256,bytes32)"))[0:10]
  def self.calculate_commit_epoch_selector
    "78e2de06" # Calculated with ethers.js
  end

  def self.encode_uint256(value)
    value.to_i.to_s(16).rjust(64, '0')
  end

  def self.encode_bytes32(value)
    # merkle_root is already a hex string (from MerkleTreeService)
    val = value.to_s
    val = val[2..-1] if val.start_with?('0x')
    val.rjust(64, '0')
  end

  def self.wait_for_receipt(rpc, tx_hash, max_wait = 60)
    start_time = Time.now
    while Time.now - start_time < max_wait
      sleep 2
      receipt = rpc.eth_get_transaction_receipt(tx_hash)
      return receipt if receipt && receipt['blockNumber']
    end
    Rails.logger.warn("Transaction receipt not found after #{max_wait}s")
    nil
  end
end
