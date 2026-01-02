require 'digest'
require 'eth'
require_relative 'rpc_client_service'
require_relative 'token_transfer_service'

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

      # Create reward records and transfer tokens
      Rails.logger.info("Processing #{rewards_data.length} rewards for epoch #{epoch_id}")

      # Initialize token transfer service
      transfer_service = TokenTransferService.new

      # Check reward wallet balance
      reward_balance = transfer_service.get_reward_wallet_balance
      total_rewards = rewards_data.sum { |r| r[:reward_amount] }

      Rails.logger.info("Reward wallet balance: #{reward_balance / 10**18.0} DEVPN")
      Rails.logger.info("Total rewards to distribute: #{total_rewards / 10**18.0} DEVPN")

      if reward_balance < total_rewards
        Rails.logger.error("Insufficient balance in reward wallet!")
        Rails.logger.error("Need: #{total_rewards / 10**18.0} DEVPN, Have: #{reward_balance / 10**18.0} DEVPN")
        epoch.update!(status: :pending)
        return false
      end

      # Process each reward
      rewards_data.each do |reward_data|
        node = reward_data[:node]
        node_address = node.is_a?(Node) ? node.address : node
        amount = reward_data[:reward_amount]

        # Skip if amount is 0
        next if amount == 0 || amount.nil?

        # Create reward record
        reward = Reward.create!(
          node: node,
          epoch: epoch,
          amount: amount,
          merkle_proof: '[]', # Empty proof, not needed for direct transfer
          claimed: false
        )

        Rails.logger.info("Created reward record: node=#{node_address}, amount=#{amount}")

        # Transfer tokens from reward wallet to node
        transfer_result = transfer_service.transfer_to_node(node_address, amount)

        if transfer_result[:success]
          Rails.logger.info("✅ Transferred #{amount} DEVPN to #{node_address}")
          reward.update!(claimed: true)
        else
          Rails.logger.error("❌ Failed to transfer tokens to #{node_address}")
          Rails.logger.error("   Error: #{transfer_result[:error]}")
          # Will retry in next settlement cycle
        end
      end

      # Update epoch
      epoch.update!(
        merkle_root: nil, # No longer needed
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
end
