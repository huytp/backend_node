require 'digest'
require 'keccak'

class MerkleTreeService
  def self.build_tree(rewards_data)
    # rewards_data: [{ node: node, amount: amount }, ...]
    # Match contract: keccak256(abi.encodePacked(recipient, amount))
    leaves = rewards_data.map do |reward|
      node_address = reward[:node].is_a?(Node) ? reward[:node].address : reward[:node]
      hash_leaf(node_address, reward[:amount])
    end

    build_merkle_tree(leaves)
  end

  def self.generate_proof(leaves, index)
    # Build full tree to generate proof correctly
    tree = build_full_tree(leaves)
    proof = []
    current_index = index
    current_level = leaves.dup
    current_level_index = 0

    while current_level.length > 1
      if current_index % 2 == 0
        # Left node, need right sibling
        sibling_index = current_index + 1
        if sibling_index < current_level.length
          proof << current_level[sibling_index]
        end
      else
        # Right node, need left sibling
        sibling_index = current_index - 1
        proof << current_level[sibling_index]
      end

      # Move to parent level
      current_index = current_index / 2
      current_level = build_next_level(current_level)
    end

    proof
  end

  def self.build_full_tree(leaves)
    # Build tree and return all levels for proof generation
    levels = [leaves.dup]
    current = leaves.dup

    while current.length > 1
      current = build_next_level(current)
      levels << current.dup
    end

    levels
  end

  # Hash a single leaf (match contract: keccak256(abi.encodePacked(recipient, amount)))
  def self.hash_leaf(node_address, amount)
    # Remove 0x prefix if present
    address_hex = node_address.to_s
    address_hex = address_hex[2..-1] if address_hex.start_with?('0x')
    address_bytes = [address_hex].pack('H*')

    # Encode amount as uint256 (32 bytes, big-endian)
    amount = amount.to_i
    # Convert to hex, pad to 64 hex chars (32 bytes)
    amount_hex = amount.to_s(16).rjust(64, '0')
    amount_bytes = [amount_hex].pack('H*')

    # abi.encodePacked(address, uint256) = address (20 bytes) + uint256 (32 bytes) = 52 bytes
    packed = address_bytes + amount_bytes

    # keccak256 hash (Ethereum uses keccak256, not SHA3-256)
    # Note: Keccak::Digest.new(:sha3_256) is actually keccak256 in Ruby
    hash = Keccak::Digest.new(:sha3_256).update(packed).digest
    hash.unpack('H*').first
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
        # Pair exists - Match contract logic: keccak256(abi.encodePacked(left, right))
        # Contract sorts: if (computedHash < proof[i]) then left first, else right first
        left = [leaves[i]].pack('H*')
        right = [leaves[i + 1]].pack('H*')

        # Sort: smaller hash goes first (match contract logic)
        if leaves[i] < leaves[i + 1]
          packed = left + right
        else
          packed = right + left
        end

        hash = Keccak::Digest.new(:sha3_256).update(packed).digest
        level << hash.unpack('H*').first
      else
        # Odd number, duplicate last
        leaf_bytes = [leaves[i]].pack('H*')
        packed = leaf_bytes + leaf_bytes
        hash = Keccak::Digest.new(:sha3_256).update(packed).digest
        level << hash.unpack('H*').first
      end
      i += 2
    end

    level
  end
end

