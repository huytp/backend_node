# Settlement Service Setup

## SETTLEMENT_PRIVATE_KEY

`SETTLEMENT_PRIVATE_KEY` là private key dùng để backend sign và gửi transaction commit epoch lên blockchain.

### Cách tạo SETTLEMENT_PRIVATE_KEY

#### Option 1: Sử dụng script Ruby (Khuyến nghị)

```bash
cd backend
ruby scripts/generate_settlement_key.rb
```

Script sẽ tạo một key pair mới và hiển thị:
- Address (địa chỉ wallet)
- Private key (không có 0x prefix)

#### Option 2: Sử dụng script Node.js

```bash
cd blockchain
node scripts/generate-key.js
```

Sau đó copy private key (không có 0x prefix) vào `SETTLEMENT_PRIVATE_KEY`.

#### Option 3: Sử dụng Ruby console

```ruby
require 'eth'
key = Eth::Key.new
puts "Address: #{key.address}"
puts "Private Key: #{key.private_hex}" # Không có 0x prefix
```

### Cấu hình

Có 2 cách cấu hình:

#### Option 1: Dùng biến riêng trong backend/.env (Khuyến nghị cho production)

Thêm vào `backend/.env`:

```bash
SETTLEMENT_PRIVATE_KEY=your_64_char_hex_string_without_0x
REWARD_CONTRACT_ADDRESS=0x...
RPC_URL=https://polygon-amoy.gateway.tatum.io/
TATUM_API_KEY=your_api_key
```

#### Option 2: Dùng chung với blockchain/.env (Tiện cho development)

Backend sẽ tự động fallback sang:
- `PRIVATE_KEY` từ `blockchain/.env` (nếu không có `SETTLEMENT_PRIVATE_KEY`)
- `REWARD_ADDRESS` từ `blockchain/.env` (nếu không có `REWARD_CONTRACT_ADDRESS`)

Vậy bạn có thể chỉ cần đảm bảo `blockchain/.env` có:
```bash
PRIVATE_KEY=your_64_char_hex_string_without_0x
REWARD_ADDRESS=0x...
```

Và backend sẽ tự động dùng các giá trị này.

**Lưu ý:**
- Private key KHÔNG có prefix `0x`
- Private key phải là 64 ký tự hex (32 bytes)
- Nếu dùng chung `PRIVATE_KEY`, đảm bảo address đó có quyền gọi `commitEpoch`

### Yêu cầu

1. **Fund address với MATIC**
   - Address cần có MATIC để trả gas fees
   - Testnet: https://faucet.polygon.technology/
   - Mainnet: Chuyển MATIC từ wallet khác

2. **Contract permissions**
   - Address phải có quyền gọi `commitEpoch` trên Reward contract
   - Thường là owner của contract hoặc được authorize

3. **Security**
   - ⚠️ **KHÔNG commit private key vào git**
   - Sử dụng secrets manager trong production (AWS Secrets Manager, HashiCorp Vault, etc.)
   - Backup private key ở nơi an toàn
   - Rotate key nếu bị lộ

### Kiểm tra

Sau khi cấu hình, kiểm tra:

```bash
# Trong Rails console
rails console

# Kiểm tra key có load được không
key = Eth::Key.new(priv: ENV['SETTLEMENT_PRIVATE_KEY'])
puts "Address: #{key.address}"

# Kiểm tra balance (cần RPC client)
# ...
```

### Troubleshooting

**Lỗi: "Invalid private key"**
- Kiểm tra private key không có `0x` prefix
- Kiểm tra đúng 64 ký tự hex

**Lỗi: "Insufficient funds"**
- Address chưa có MATIC
- Fund address với MATIC từ faucet

**Lỗi: "Transaction failed"**
- Kiểm tra address có quyền gọi contract không
- Kiểm tra contract address đúng chưa
- Kiểm tra RPC URL và API key

