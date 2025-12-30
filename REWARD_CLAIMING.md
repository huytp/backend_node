# Reward Claiming Guide

## Overview

Sau khi epoch được settled và committed on-chain, node có thể claim rewards của mình từ smart contract. Rewards sẽ được mint và chuyển trực tiếp vào ví của node.

## Flow

1. **Epoch Settlement** (tự động qua `SettlementJob`)
   - Tính rewards cho từng node
   - Build Merkle tree
   - Commit Merkle root lên blockchain
   - Lưu rewards với merkle proof vào database

2. **Claim Rewards** (node tự claim)
   - Node kiểm tra unclaimed rewards
   - Node gọi API để claim
   - Backend build transaction gọi `claimReward()` trên smart contract
   - Smart contract verify merkle proof
   - Nếu hợp lệ, mint tokens vào ví node
   - Update `claimed = true` trong database

## API Endpoints

### 1. Get Unclaimed Rewards

Lấy danh sách rewards chưa claim của node.

```bash
GET /rewards/unclaimed?node=<node_address>
```

**Response:**
```json
{
  "node": "0x123...",
  "unclaimed_count": 3,
  "total_unclaimed_amount": 15000,
  "rewards": [
    {
      "epoch_id": 225,
      "amount": 5000,
      "merkle_root": "0xabc...",
      "epoch_end_time": "2025-12-30T12:00:00Z"
    },
    ...
  ]
}
```

### 2. Claim Reward

Claim reward cho một epoch cụ thể.

```bash
POST /rewards/claim
Content-Type: application/json

{
  "node": "0x123...",
  "epoch_id": 225,
  "private_key": "0x..."
}
```

**Response (Success):**
```json
{
  "success": true,
  "tx_hash": "0xdef...",
  "amount": 5000,
  "epoch_id": 225,
  "node": "0x123..."
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Reward already claimed"
}
```

### 3. Get Merkle Proof

Nếu node muốn claim trực tiếp từ smart contract (không qua backend).

```bash
GET /rewards/proof?node=<node_address>&epoch_id=<epoch_id>
```

**Response:**
```json
{
  "epoch": 225,
  "node": "0x123...",
  "amount": 5000,
  "proof": ["0xabc...", "0xdef...", ...],
  "merkle_root": "0x..."
}
```

## Using the CLI Script

### Setup

1. Ensure `.env` in `vpn-node/` contains:
```env
BACKEND_URL=http://localhost:3000
NODE_ADDRESS=0x...
PRIVATE_KEY=0x...
```

### Commands

#### Check unclaimed rewards and claim latest:
```bash
cd vpn-node
bin/claim-reward
```

#### Claim specific epoch:
```bash
bin/claim-reward 225
```

### Example Output:
```
🔄 Claiming reward for epoch 225...
   Node: 0x123...

📊 Unclaimed Rewards Summary:
   Total unclaimed: 3
   Total amount: 15000 tokens

   Rewards by epoch:
   - Epoch 225: 5000 tokens
   - Epoch 224: 4500 tokens
   - Epoch 223: 5500 tokens

🔄 Submitting claim transaction for epoch 225...

✅ Reward claimed successfully!
   Epoch: 225
   Amount: 5000 tokens
   Transaction: https://amoy.polygonscan.com/tx/0xdef...
```

## Direct Smart Contract Interaction

Node cũng có thể claim trực tiếp từ smart contract nếu muốn:

```javascript
// Get proof from backend API
const response = await fetch(
  `${BACKEND_URL}/rewards/proof?node=${nodeAddress}&epoch_id=${epochId}`
);
const { epoch, amount, proof } = await response.json();

// Call smart contract
const rewardContract = new ethers.Contract(
  REWARD_CONTRACT_ADDRESS,
  rewardABI,
  signer
);

const tx = await rewardContract.claimReward(epoch, amount, proof);
await tx.wait();
```

## Smart Contract Function

```solidity
function claimReward(
    uint epoch,
    uint amount,
    bytes32[] calldata proof
) external {
    require(epochRoots[epoch] != bytes32(0), "Epoch not committed");
    require(!claimed[epoch][msg.sender], "Already claimed");
    require(verifyProof(epoch, msg.sender, amount, proof), "Invalid proof");

    claimed[epoch][msg.sender] = true;

    // Mint from node rewards pool
    token.mintNodeReward(msg.sender, amount);

    emit RewardClaimed(msg.sender, epoch, amount);
}
```

## Security Notes

1. **Private Key Security**: Private key chỉ được sử dụng để sign transaction, không được lưu trữ ở backend
2. **Merkle Proof Verification**: Smart contract verify proof trước khi mint tokens
3. **Double-Claim Prevention**: Smart contract track claimed status để prevent double-claiming
4. **Rate Limiting**: Backend có rate limiting để avoid overwhelming RPC provider

## Troubleshooting

### "Epoch not committed"
- Epoch chưa được settled/committed on-chain
- Chờ `SettlementJob` chạy (mỗi 5 phút)

### "Already claimed"
- Reward đã được claim trước đó
- Check transaction history trên Polygonscan

### "Invalid proof"
- Merkle proof không hợp lệ
- Contact admin để investigate

### "RPC call failed: 429"
- Rate limit exceeded
- Đợi và retry, backend có automatic retry logic

## Monitoring

### Check claim status:
```bash
curl "http://localhost:3000/rewards/unclaimed?node=0x123..."
```

### Verify on blockchain:
```
https://amoy.polygonscan.com/address/<REWARD_CONTRACT_ADDRESS>
```

### Check token balance:
```
https://amoy.polygonscan.com/token/<TOKEN_ADDRESS>?a=<NODE_ADDRESS>
```

