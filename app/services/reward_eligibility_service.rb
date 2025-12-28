require 'httparty'
require 'json'

class RewardEligibilityService
  # Ngưỡng hiệu suất tối thiểu để nhận reward
  PERFORMANCE_THRESHOLD = 60.0 # Quality score >= 60
  AI_SCORE_THRESHOLD = 0.7 # AI score >= 0.7 để được coi là "node tốt"

  # Kiểm tra xem node có đủ điều kiện nhận reward không
  def self.eligible_for_reward?(node, traffic_record, request_source:)
    # 1. KHÔNG được request nếu node tự ý request (không qua hệ thống)
    # Node tự request khi request_source là :node_self hoặc không có request_source hợp lệ
    if request_source == :node_self || ![:session_end, :epoch_end, :performance_threshold, :ai_confirmed].include?(request_source)
      return { eligible: false, reason: 'Node tự ý request reward - không được phép' }
    end

    # 2. KHÔNG được request nếu traffic bất thường
    if traffic_anomaly?(traffic_record, node)
      return { eligible: false, reason: 'Traffic bất thường được phát hiện' }
    end

    # 3. KHÔNG được request nếu chưa qua AI scoring
    ai_score_result = check_ai_scoring(node)
    unless ai_score_result[:scored]
      return { eligible: false, reason: 'Chưa qua AI scoring' }
    end

    # 4. ĐƯỢC request khi kết thúc VPN session
    if request_source == :session_end
      return { eligible: true, reason: 'Kết thúc VPN session' }
    end

    # 5. ĐƯỢC request khi kết thúc epoch
    if request_source == :epoch_end
      return { eligible: true, reason: 'Kết thúc epoch' }
    end

    # 6. ĐƯỢC request khi đạt ngưỡng hiệu suất
    if performance_threshold_met?(node)
      return { eligible: true, reason: 'Đạt ngưỡng hiệu suất' }
    end

    # 7. ĐƯỢC request khi được AI xác nhận là "node tốt"
    if ai_score_result[:score] >= AI_SCORE_THRESHOLD
      return { eligible: true, reason: 'Được AI xác nhận là node tốt' }
    end

    { eligible: false, reason: 'Không đáp ứng điều kiện reward' }
  end

  # Kiểm tra traffic có bất thường không
  def self.traffic_anomaly?(traffic_record, node)
    # Lấy các traffic records gần đây của node (trừ record hiện tại)
    begin
      recent_records = TrafficRecord
        .where(node: node)
        .where.not(id: traffic_record.id)
        .where('created_at > ?', 1.hour.ago)
        .order(created_at: :desc)
        .limit(20)

      return false if recent_records.count < 3 # Cần ít nhất 3 records để so sánh
    rescue ActiveRecord::StatementInvalid, PG::Error => e
      Rails.logger.error("Database error detected in traffic_anomaly? check: #{e.message}")
      # If database error occurs, assume no anomaly to avoid blocking operations
      # The error will be handled by the calling code
      return false
    end

    # Tính toán traffic trung bình
    avg_traffic = recent_records.average(:traffic_mb) || 0
    std_dev = calculate_std_dev(recent_records.map(&:traffic_mb))

    # Nếu traffic hiện tại vượt quá 3 standard deviations, coi là bất thường
    if std_dev > 0
      z_score = (traffic_record.traffic_mb - avg_traffic) / std_dev
      return z_score.abs > 3.0
    end

    # Nếu traffic quá lớn so với trung bình (ví dụ: > 10x), coi là bất thường
    if avg_traffic > 0 && traffic_record.traffic_mb > avg_traffic * 10
      return true
    end

    false
  end

  # Kiểm tra AI scoring
  def self.check_ai_scoring(node)
    ai_routing_url = ENV['AI_ROUTING_URL'] || 'http://localhost:8000'

    begin
      response = HTTParty.get(
        "#{ai_routing_url}/node/#{node.address}/score",
        headers: { 'Content-Type' => 'application/json' },
        timeout: 5
      )

      if response.success?
        data = JSON.parse(response.body)
        {
          scored: true,
          score: data['score'].to_f,
          node: node.address
        }
      else
        { scored: false, reason: 'AI routing service không phản hồi' }
      end
    rescue => e
      Rails.logger.error("Failed to check AI scoring for node #{node.address}: #{e.message}")
      { scored: false, reason: "Lỗi khi gọi AI scoring: #{e.message}" }
    end
  end

  # Kiểm tra node có đạt ngưỡng hiệu suất không
  def self.performance_threshold_met?(node)
    quality_score = node.calculate_quality_score
    quality_score >= PERFORMANCE_THRESHOLD
  end

  # Tính standard deviation
  def self.calculate_std_dev(values)
    return 0 if values.empty? || values.length < 2

    mean = values.sum.to_f / values.length
    variance = values.sum { |v| (v - mean) ** 2 } / values.length
    Math.sqrt(variance)
  end

  # Kiểm tra node có được AI xác nhận là "node tốt" không
  def self.is_good_node?(node)
    ai_result = check_ai_scoring(node)
    return false unless ai_result[:scored]

    ai_result[:score] >= AI_SCORE_THRESHOLD
  end

  # Batch check eligibility cho nhiều traffic records
  def self.batch_check_eligibility(node, traffic_records, request_source:)
    results = []

    traffic_records.each do |traffic_record|
      result = eligible_for_reward?(node, traffic_record, request_source: request_source)
      results << {
        traffic_record_id: traffic_record.id,
        eligible: result[:eligible],
        reason: result[:reason]
      }
    end

    results
  end
end

