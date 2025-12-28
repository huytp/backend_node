# Traffic Records Flow

## Tổng quan

Traffic records được gửi từ **VPN Node Agent** lên **Backend** để tracking traffic và tính reward.

## Flow

### 1. Node Agent tạo Traffic Record

**File:** `vpn-node/node-agent/lib/traffic_meter.rb`

```ruby
# Node agent tạo traffic record với signature
record = traffic_meter.create_traffic_record(session_id, epoch_id)
# => {
#   node: "0x...",
#   session_id: "uuid",
#   traffic_mb: 100.5,
#   epoch_id: 1,
#   timestamp: 1234567890,
#   signature: "0x..."
# }
```

### 2. Node Agent gửi lên Backend

**File:** `vpn-node/node-agent/lib/traffic_sender.rb`

Node agent sử dụng `TrafficSender` để gửi traffic records:

```ruby
traffic_sender = TrafficSender.new(signer, backend_url, traffic_meter)
traffic_sender.send_traffic_record(session_id, epoch_id)
```

**Endpoints:**
- `POST /nodes/traffic` - Gửi một traffic record
- `POST /nodes/traffic/batch` - Gửi nhiều traffic records cùng lúc

### 3. Backend nhận và xử lý

**File:** `backend/app/controllers/nodes/traffic_controller.rb`

Backend sẽ:
1. **Verify signature** - Kiểm tra signature của traffic record
2. **Tìm VPN connection** - Tìm connection từ session_id
3. **Tạo TrafficRecord** - Lưu vào database
4. **Tự động kiểm tra eligibility** - Callback `after_create` sẽ:
   - Kiểm tra AI scoring
   - Kiểm tra performance threshold
   - Kiểm tra AI confirmation
   - Cập nhật `reward_eligible`, `ai_scored`, `has_anomaly`

### 4. Khi nào gửi Traffic Records?

#### a) Khi VPN session kết thúc
```ruby
# Trong node agent, khi session disconnect
traffic_sender.send_on_session_end(session_id, epoch_id)
```

#### b) Định kỳ (periodic reporting)
```ruby
# Trong traffic_report_loop
# Gửi traffic records theo interval (ví dụ: mỗi 5 phút)
```

#### c) Khi đạt ngưỡng traffic
```ruby
# Khi traffic vượt quá một ngưỡng nhất định
if traffic_mb > threshold
  send_traffic_record(session_id, epoch_id)
end
```

## Request Format

### Single Traffic Record

**POST** `/nodes/traffic`

```json
{
  "node": "0x1234...",
  "session_id": "uuid-connection-id",
  "traffic_mb": 100.5,
  "epoch_id": 1,
  "timestamp": 1234567890,
  "signature": "0xabcd..."
}
```

**Response:**
```json
{
  "id": 123,
  "node": "0x1234...",
  "session_id": "uuid-connection-id",
  "traffic_mb": 100.5,
  "epoch_id": 1,
  "reward_eligible": true,
  "eligibility_reason": "Kết thúc VPN session",
  "ai_scored": true,
  "ai_score": 0.85,
  "created_at": "2024-01-01T00:00:00Z"
}
```

### Batch Traffic Records

**POST** `/nodes/traffic/batch`

```json
{
  "node": "0x1234...",
  "records": [
    {
      "session_id": "uuid-1",
      "traffic_mb": 100.5,
      "epoch_id": 1,
      "timestamp": 1234567890,
      "signature": "0xabcd..."
    },
    {
      "session_id": "uuid-2",
      "traffic_mb": 50.2,
      "epoch_id": 1,
      "timestamp": 1234567891,
      "signature": "0xefgh..."
    }
  ]
}
```

**Response:**
```json
{
  "created": 2,
  "failed": 0,
  "results": [
    {
      "id": 123,
      "session_id": "uuid-1",
      "traffic_mb": 100.5,
      "reward_eligible": true,
      "ai_scored": true
    },
    {
      "id": 124,
      "session_id": "uuid-2",
      "traffic_mb": 50.2,
      "reward_eligible": true,
      "ai_scored": true
    }
  ],
  "errors": []
}
```

## Security

1. **Signature Verification**
   - Mỗi traffic record phải có signature hợp lệ
   - Signature được tạo từ node's private key
   - Backend verify signature trước khi lưu

2. **Node Authentication**
   - Node address phải match với signature
   - Node phải tồn tại trong database

3. **Request Source Tracking**
   - Backend track `request_source` để biết record được tạo từ đâu
   - Node tự request sẽ bị từ chối (request_source = `node_self`)

## Integration với Reward Eligibility

Khi traffic record được tạo:
1. ✅ Tự động kiểm tra AI scoring
2. ✅ Tự động kiểm tra performance threshold
3. ✅ Tự động kiểm tra AI confirmation
4. ✅ Tự động phát hiện traffic anomaly
5. ✅ Cập nhật `reward_eligible` status

Xem thêm: `REWARD_ELIGIBILITY.md`

## Example Usage trong Node Agent

```ruby
require_relative 'traffic_sender'

# Initialize
traffic_sender = TrafficSender.new(signer, backend_url, traffic_meter)

# Gửi khi session kết thúc
traffic_sender.send_on_session_end(session_id, epoch_id)

# Gửi nhiều records cùng lúc
session_ids = ['uuid-1', 'uuid-2', 'uuid-3']
traffic_sender.send_traffic_records_batch(session_ids, epoch_id)
```

## Notes

- Traffic records phải được gửi với signature hợp lệ
- Backend sẽ tự động kiểm tra eligibility khi nhận record
- Node không thể tự request reward - chỉ hệ thống mới có thể tạo reward request
- Traffic records được link với VPN connection qua `session_id` (connection_id)

