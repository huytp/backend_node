# Reward Eligibility Logic

## Tổng quan

Hệ thống kiểm tra điều kiện reward để đảm bảo chỉ các node đáp ứng yêu cầu mới được nhận reward.

## Reward ĐƯỢC request khi:

1. **Kết thúc VPN session** (`session_end`)
   - Tự động kiểm tra khi `VpnConnection` chuyển sang trạng thái `disconnected`
   - Callback `check_reward_eligibility_on_disconnect` được gọi

2. **Kết thúc epoch** (`epoch_end`)
   - Kiểm tra khi `SettlementService.settle_epoch` được gọi
   - Chỉ các traffic records đủ điều kiện mới được tính vào reward

3. **Đạt ngưỡng hiệu suất** (`performance_threshold`)
   - Quality score >= 60 (PERFORMANCE_THRESHOLD)
   - Tự động kiểm tra khi tạo `TrafficRecord`

4. **Được AI xác nhận là "node tốt"** (`ai_confirmed`)
   - AI score >= 0.7 (AI_SCORE_THRESHOLD)
   - Tự động kiểm tra khi tạo `TrafficRecord`

## Reward KHÔNG được request khi:

1. **Node tự ý request** (`node_self`)
   - Node tự gọi API mà không qua hệ thống
   - Tất cả các request_source khác ngoài 4 loại trên đều bị từ chối

2. **Traffic bất thường**
   - Traffic vượt quá 3 standard deviations so với trung bình
   - Traffic > 10x so với trung bình
   - Phát hiện bằng Z-score analysis

3. **Chưa qua AI scoring**
   - AI Routing service không phản hồi
   - Node chưa có AI score

## Implementation

### Files chính:

1. **`app/services/reward_eligibility_service.rb`**
   - Service chính để kiểm tra điều kiện reward
   - Methods:
     - `eligible_for_reward?`: Kiểm tra eligibility
     - `traffic_anomaly?`: Phát hiện traffic bất thường
     - `check_ai_scoring`: Kiểm tra AI score từ AI Routing
     - `performance_threshold_met?`: Kiểm tra ngưỡng hiệu suất
     - `is_good_node?`: Kiểm tra node có được AI xác nhận không

2. **`app/models/traffic_record.rb`**
   - Callback `after_create` để tự động kiểm tra AI scoring và eligibility
   - Lưu trạng thái: `ai_scored`, `ai_score`, `reward_eligible`, `has_anomaly`, `request_source`

3. **`app/models/vpn_connection.rb`**
   - Callback `after_update` khi disconnect để kiểm tra reward eligibility
   - Cập nhật tất cả traffic records của session

4. **`app/models/epoch.rb`**
   - Method `calculate_rewards_with_eligibility`: Chỉ tính reward cho records đủ điều kiện
   - Được gọi bởi `SettlementService`

5. **`app/services/settlement_service.rb`**
   - Sử dụng `calculate_rewards_with_eligibility` thay vì `calculate_rewards`

### Database Migration:

**`db/migrate/007_add_reward_tracking_fields.rb`**
- Thêm các trường vào `traffic_records`:
  - `ai_scored`: boolean
  - `ai_score`: float
  - `has_anomaly`: boolean
  - `reward_eligible`: boolean
  - `request_source`: string
  - `eligibility_reason`: text

### API Endpoints:

1. **`GET /rewards/eligibility/:traffic_record_id`**
   - Kiểm tra eligibility của một traffic record
   - Query params: `request_source` (optional, default: `node_self`)

2. **`GET /rewards/verify/:epoch_id`**
   - Đã được cập nhật để hiển thị thông tin eligibility cho từng traffic record

## Workflow

### Khi tạo TrafficRecord:
1. Tự động kiểm tra AI scoring
2. Kiểm tra performance threshold
3. Kiểm tra AI confirmation
4. Cập nhật trạng thái vào record

### Khi VPN session kết thúc:
1. Callback `check_reward_eligibility_on_disconnect` được gọi
2. Kiểm tra eligibility cho tất cả traffic records của session
3. Cập nhật với `request_source: 'session_end'`

### Khi epoch kết thúc:
1. `SettlementService.settle_epoch` được gọi
2. Sử dụng `calculate_rewards_with_eligibility`
3. Chỉ tính reward cho các records có `reward_eligible: true`

## Configuration

- `PERFORMANCE_THRESHOLD = 60.0`: Ngưỡng quality score
- `AI_SCORE_THRESHOLD = 0.7`: Ngưỡng AI score để được coi là "node tốt"
- Anomaly detection: Z-score > 3.0 hoặc traffic > 10x trung bình

## Notes

- Tất cả các kiểm tra đều có error handling để tránh crash khi AI Routing service không available
- Traffic records được track đầy đủ để audit và debug
- Node không thể tự request reward - chỉ hệ thống mới có thể tạo reward request

