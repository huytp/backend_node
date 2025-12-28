# Backend Services (Ruby on Rails)

## Mục tiêu
- Điều phối hệ thống
- Không giữ tiền
- Không giữ key

## Kiến trúc

### API Gateway
Entry point cho tất cả requests (Rails routes)

### Node Service
Quản lý node registration, heartbeat, status

### Routing Service
Xử lý VPN connection/disconnection (tích hợp AI Routing)

### Settlement Service
- Cron job mỗi 1h (Sidekiq)
- Tổng hợp traffic
- Áp dụng công thức: `reward = trafficMB × quality × reputation`
- Build Merkle tree
- Commit root on-chain

## API Endpoints

### Node
- `POST /nodes/heartbeat`: Nhận heartbeat từ node
- `GET /nodes/status/:address`: Lấy trạng thái node
- `GET /nodes/status`: Lấy danh sách nodes

### VPN
- `POST /vpn/connect`: Kết nối VPN
- `POST /vpn/disconnect`: Ngắt kết nối VPN
- `GET /vpn/status/:connection_id`: Lấy trạng thái connection

### Reward
- `GET /rewards/epoch/:id`: Lấy thông tin epoch
- `GET /rewards/proof?node=0x...&epoch=123`: Lấy merkle proof để claim
- `GET /rewards/epochs`: Lấy danh sách epochs
- `GET /rewards/verify/:epoch_id?node=0x...`: Verify reward calculation

## Installation

```bash
# Install dependencies
bundle install

# Setup database
rails db:create
rails db:migrate

# Start server
rails server
```

## Configuration

Copy `.env.example` to `.env` và cấu hình:

- `AI_ROUTING_URL`: URL của AI Routing Engine
- `REDIS_URL`: Redis connection cho Sidekiq
- Blockchain contract addresses

## Background Jobs

Settlement job chạy tự động mỗi 1 giờ qua Sidekiq:

```bash
# Start Sidekiq
bundle exec sidekiq
```

## Database Schema

- `nodes`: Thông tin nodes
- `heartbeats`: Heartbeat records
- `vpn_connections`: VPN connections
- `traffic_records`: Traffic records
- `epochs`: Epoch information
- `rewards`: Reward records với merkle proof

## Integration

- **AI Routing Engine**: Gửi metrics và nhận route selection
- **Blockchain**: Commit merkle roots và reputation scores
