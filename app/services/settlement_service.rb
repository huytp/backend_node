require 'digest'

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
    # TODO: Implement blockchain interaction
    # Sử dụng web3 hoặc ethereum.rb để gọi contract
    Rails.logger.info("Committing epoch #{epoch_id} with root #{merkle_root} to blockchain")

    # Example với ethereum.rb:
    # contract = Ethereum::Contract.create(
    #   name: "Reward",
    #   address: ENV['REWARD_CONTRACT_ADDRESS'],
    #   abi: [...]
    # )
    # contract.transact.commit_epoch(epoch_id, merkle_root)
  end
end
