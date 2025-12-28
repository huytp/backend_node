# Epoch Management

## Tổng quan

Epoch được tạo tự động theo chu kỳ 5 phút để quản lý rewards và traffic records.

## Epoch Lifecycle

```
Tạo Epoch (pending)
  ↓
Thu thập Traffic Records
  ↓
Epoch kết thúc (end_time)
  ↓
Settlement (processing)
  ↓
Commit lên Blockchain (committed)
```

## Files liên quan

### 1. **EpochService** (`app/services/epoch_service.rb`)

Service quản lý việc tạo và lấy epochs:

- `get_or_create_current_epoch`: Lấy epoch hiện tại hoặc tạo mới
- `create_new_epoch`: Tạo epoch mới với epoch_id tiếp theo
- `close_current_epoch`: Đóng epoch đã hết thời gian
- `current_epoch`: Lấy epoch hiện tại (không tạo mới)
- `current_epoch_id`: Lấy epoch_id hiện tại

### 2. **EpochJob** (`app/jobs/epoch_job.rb`)

Background job chạy mỗi 1 phút để:
- Đóng epoch cũ nếu đã hết thời gian
- Đảm bảo có epoch hiện tại

### 3. **SettlementJob** (`app/jobs/settlement_job.rb`)

Background job chạy mỗi 5 phút để:
- Tìm epochs đã kết thúc (status: 'pending', end_time <= now)
- Gọi `SettlementService.settle_epoch` để tính rewards và commit

## Cấu hình

**File:** `config/initializers/sidekiq.rb`

```ruby
# Epoch Job - chạy mỗi 1 phút
Sidekiq::Cron::Job.create(
  name: 'Epoch Job - every 1 minute',
  cron: '* * * * *',
  class: 'EpochJob'
)

# Settlement Job - chạy mỗi 5 phút
Sidekiq::Cron::Job.create(
  name: 'Settlement Job - every 5 minutes',
  cron: '*/5 * * * *',
  class: 'SettlementJob'
)
```

## Epoch Duration

- **Duration:** 5 phút (theo smart contract)
- **Constant:** `EpochService::EPOCH_DURATION = 5.minutes`

## API Endpoints

### GET /rewards/current_epoch

Lấy epoch hiện tại (tự động tạo nếu chưa có):

```json
{
  "epoch_id": 1,
  "start_time": "2024-01-01T00:00:00Z",
  "end_time": "2024-01-01T00:05:00Z",
  "status": "pending",
  "remaining_seconds": 180
}
```

### GET /rewards/epochs

Lấy danh sách epochs (100 epochs gần nhất)

## Khi nào Epoch được tạo?

1. **Tự động** - `EpochJob` chạy mỗi 1 phút:
   - Kiểm tra xem có epoch hiện tại không
   - Nếu không có hoặc đã hết thời gian, tạo epoch mới

2. **On-demand** - Khi gọi `EpochService.get_or_create_current_epoch`:
   - Tự động tạo nếu chưa có epoch hiện tại
   - Được sử dụng khi tạo traffic records

## Khi nào Epoch được settle?

1. **Tự động** - `SettlementJob` chạy mỗi 5 phút:
   - Tìm epochs có `status: 'pending'` và `end_time <= now`
   - Gọi `SettlementService.settle_epoch` để:
     - Tính rewards (chỉ cho records đủ điều kiện)
     - Build Merkle tree
     - Tạo Reward records
     - Commit lên blockchain
     - Update status thành 'committed'

## Epoch Status

- **pending**: Epoch đang active hoặc chờ settle
- **processing**: Đang được settle
- **committed**: Đã commit lên blockchain

## Notes

- Epoch được tạo tự động, không cần manual intervention
- Mỗi epoch kéo dài 5 phút
- Traffic records được gán vào epoch hiện tại khi tạo
- Chỉ traffic records đủ điều kiện mới được tính vào reward

