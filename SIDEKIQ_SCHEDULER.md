# Sidekiq Scheduler Configuration

## Tổng quan

Sử dụng `sidekiq-scheduler` để schedule các background jobs theo cách được mô tả trong [bài viết Viblo](https://viblo.asia/p/tim-hieu-ve-gem-sidekiq-scheduler-Az45bQd6lxY).

## Cài đặt

### Gemfile
```ruby
gem 'sidekiq', '~> 7.0'
gem 'sidekiq-scheduler'
```

Chạy: `bundle install`

## Cấu hình

### 1. File `config/sidekiq.yml`

File này chứa lịch trình các jobs cần chạy định kỳ:

```yaml
:schedule:
  epoch_job:
    cron: '* * * * *'  # Mỗi phút
    class: EpochJob
    description: "Tạo và quản lý epochs mỗi 1 phút"

  settlement_job:
    cron: '*/5 * * * *'  # Mỗi 5 phút
    class: SettlementJob
    description: "Settle epochs đã kết thúc mỗi 5 phút"
```

### 2. File `config/initializers/sidekiq.rb`

Load schedule từ file YAML:

```ruby
require 'sidekiq'
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }

  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path('../sidekiq.yml', __FILE__))
    Sidekiq::Scheduler.reload_schedule!
  end
end
```

### 3. File `config/initializers/sidekiq_web.rb`

Thêm scheduler web UI:

```ruby
require 'sidekiq/web'
require 'sidekiq-scheduler/web'
```

## Scheduled Jobs

### 1. **EpochJob**
- **Cron:** `* * * * *` (mỗi phút)
- **Mục đích:** Tạo và quản lý epochs
- **File:** `app/jobs/epoch_job.rb`

### 2. **SettlementJob**
- **Cron:** `*/5 * * * *` (mỗi 5 phút)
- **Mục đích:** Settle epochs đã kết thúc
- **File:** `app/jobs/settlement_job.rb`

## Cron Expression Format

### 5 tham số (không có giây):
```
* * * * *
│ │ │ │ │
│ │ │ │ └─── Day of week (0-6, 0 = Sunday)
│ │ │ └───── Month (1-12)
│ │ └─────── Day of month (1-31)
│ └───────── Hour (0-23)
└─────────── Minute (0-59)
```

### 6 tham số (có giây):
```
* * * * * *
│ │ │ │ │ │
│ │ │ │ │ └─── Day of week (0-6)
│ │ │ │ └───── Month (1-12)
│ │ │ └─────── Day of month (1-31)
│ │ └───────── Hour (0-23)
│ └─────────── Minute (0-59)
└───────────── Second (0-59)
```

### Ví dụ:
- `* * * * *` - Mỗi phút
- `*/5 * * * *` - Mỗi 5 phút
- `0 * * * *` - Mỗi giờ (vào phút 0)
- `0 0 * * *` - Mỗi ngày (vào 00:00)
- `0 0 0 * * *` - Mỗi ngày (vào 00:00:00) - với 6 tham số

## Xem Scheduled Jobs

1. Truy cập: `http://localhost:3000/sidekiq`
2. Click tab **"Scheduler"** hoặc **"Recurring Jobs"** ở menu trên
3. Xem danh sách scheduled jobs:
   - **Name:** Tên job
   - **Cron:** Cron expression
   - **Last Run:** Lần chạy cuối
   - **Next Run:** Lần chạy tiếp theo
   - **Status:** Active/Inactive

## Các loại Schedule

### 1. **cron** - Theo mô hình cron
```yaml
epoch_job:
  cron: '* * * * *'
  class: EpochJob
```

### 2. **every** - Kích hoạt theo tần số
```yaml
epoch_job:
  every: '1m'  # Mỗi 1 phút
  class: EpochJob
```

### 3. **interval** - Tương tự every
```yaml
epoch_job:
  interval: '1m'
  class: EpochJob
```

### 4. **at** - Chạy một lần tại thời điểm cụ thể
```yaml
cleanup_job:
  at: '2024/12/31 23:59:59'
  class: CleanupJob
```

### 5. **in** - Chạy sau một khoảng thời gian
```yaml
delayed_job:
  in: '1h'  # Chạy sau 1 giờ
  class: DelayedJob
```

## Tùy chọn bổ sung

```yaml
epoch_job:
  cron: '* * * * *'
  class: EpochJob
  queue: default        # Queue name
  args: ['arg1', 'arg2'] # Arguments
  description: "Mô tả job"
```

## Troubleshooting

### Jobs không chạy:
1. Kiểm tra Redis: `redis-cli ping`
2. Kiểm tra Sidekiq server đang chạy
3. Xem logs: `tail -f log/development.log`
4. Kiểm tra schedule trong Sidekiq Web UI → "Scheduler" tab

### Reload schedule:
- Restart Sidekiq server
- Hoặc trong Rails console: `Sidekiq::Scheduler.reload_schedule!`

## Tài liệu tham khảo

- [Bài viết Viblo về sidekiq-scheduler](https://viblo.asia/p/tim-hieu-ve-gem-sidekiq-scheduler-Az45bQd6lxY)
- [GitHub: sidekiq-scheduler](https://github.com/sidekiq-scheduler/sidekiq-scheduler)
- [Cron Expression Generator](https://crontab.guru/)




