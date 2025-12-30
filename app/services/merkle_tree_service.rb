require 'digest'

class MerkleTreeService
  def self.build_tree(rewards_data)
    # rewards_data: [{ node: node, amount: amount }, ...]
    leaves = rewards_data.map do |reward|
      node_address = reward[:node].is_a?(Node) ? reward[:node].address : reward[:node]
      leaf_data = "#{node_address}#{reward[:amount]}"
      Digest::SHA256.hexdigest(leaf_data)
    end

    build_merkle_tree(leaves)
  end

  def self.generate_proof(leaves, index)
    proof = []
    current_index = index
    current_leaves = leaves.dup

    while current_leaves.length > 1
      if current_index % 2 == 0
        # Left node, need right sibling
        sibling_index = current_index + 1
        if sibling_index < current_leaves.length
          proof << current_leaves[sibling_index]
        end
      else
        # Right node, need left sibling
        sibling_index = current_index - 1
        proof << current_leaves[sibling_index]
      end

      # Move to parent level
      current_index = current_index / 2
      current_leaves = build_next_level(current_leaves)
    end

    proof
  end

  private

  def self.build_merkle_tree(leaves)
    return nil if leaves.empty?
    return leaves.first if leaves.length == 1

    next_level = build_next_level(leaves)
    build_merkle_tree(next_level)
  end

  def self.build_next_level(leaves)
    level = []
    i = 0

    while i < leaves.length
      if i + 1 < leaves.length
        # Pair exists
        combined = leaves[i] + leaves[i + 1]
        level << Digest::SHA256.hexdigest(combined)
      else
        # Odd number, duplicate last
        combined = leaves[i] + leaves[i]
        level << Digest::SHA256.hexdigest(combined)
      end
      i += 2
    end

    level
  end
end

