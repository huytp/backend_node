# ⚠️ VẤN ĐỀ: Merkle Tree Hash Không Khớp

## Vấn đề phát hiện

Backend và Contract đang dùng **2 cách hash khác nhau** cho Merkle tree leaf:

### Contract (Reward.sol):
```solidity
bytes32 leaf = keccak256(abi.encodePacked(recipient, amount));
```
- Dùng **keccak256** (Ethereum standard)
- Dùng **abi.encodePacked** để pack address (20 bytes) + uint256 (32 bytes)
- Kết quả: 52 bytes được hash bằng keccak256

### Backend (MerkleTreeService.rb):
```ruby
leaf_data = "#{node_address}#{reward[:amount]}"
Digest::SHA256.hexdigest(leaf_data)
```
- Dùng **SHA256** (không phải keccak256)
- Chỉ nối string đơn giản: "0x1234...5678" + "1000000000000000000"
- Không dùng abi.encodePacked format

## Hậu quả

1. **Merkle root không khớp**: Root tính trên backend ≠ root trên contract
2. **Proof verification sẽ fail**: Nodes không thể claim rewards
3. **Transaction commit thành công nhưng không dùng được**: Epoch được commit nhưng merkle proof không verify được

## Giải pháp

Cần sửa backend để:
1. Dùng **keccak256** thay vì SHA256
2. Dùng **abi.encodePacked** format (pack address + uint256)
3. Đảm bảo cách build Merkle tree khớp với contract

## Contract verifyProof logic

Contract cũng có logic đặc biệt khi verify:
```solidity
if (computedHash < proof[i]) {
    computedHash = keccak256(abi.encodePacked(computedHash, proof[i]));
} else {
    computedHash = keccak256(abi.encodePacked(proof[i], computedHash));
}
```

Backend cần match logic này khi build tree.

