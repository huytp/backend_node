class TrafficRecord < ApplicationRecord
  belongs_to :node
  belongs_to :vpn_connection, optional: true

  validates :traffic_mb, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :signature, presence: true
  validates :epoch_id, presence: true

  after_create :check_ai_scoring_and_eligibility

  private

  def check_ai_scoring_and_eligibility
    # Kiểm tra AI scoring ngay khi tạo record
    begin
      ai_result = RewardEligibilityService.check_ai_scoring(node)

      update_columns(
        ai_scored: ai_result[:scored],
        ai_score: ai_result[:score]
      )
    rescue ActiveRecord::StatementInvalid, PG::Error => e
      Rails.logger.error("Database error detected during AI scoring for traffic record #{id}: #{e.message}")
      Rails.logger.error("Stack trace: #{e.backtrace.first(5).join("\n")}")
      begin
        update_columns(ai_scored: false, ai_score: nil)
      rescue => update_error
        Rails.logger.error("Failed to update traffic record after database error: #{update_error.message}")
      end
    rescue => e
      Rails.logger.error("Failed to check AI scoring for traffic record #{id}: #{e.message}")
      begin
        update_columns(ai_scored: false, ai_score: nil)
      rescue => update_error
        Rails.logger.error("Failed to update traffic record: #{update_error.message}")
      end
    end

    # Kiểm tra reward eligibility với các điều kiện:
    # 1. Đạt ngưỡng hiệu suất
    # 2. Được AI xác nhận là "node tốt"

    begin
      request_source = nil
      if RewardEligibilityService.performance_threshold_met?(node)
        request_source = :performance_threshold
      elsif RewardEligibilityService.is_good_node?(node)
        request_source = :ai_confirmed
      end

      if request_source
        result = RewardEligibilityService.eligible_for_reward?(
          node,
          self,
          request_source: request_source
        )

        update_columns(
          reward_eligible: result[:eligible],
          eligibility_reason: result[:reason],
          request_source: request_source.to_s
        )
      end
    rescue ActiveRecord::StatementInvalid, PG::Error => e
      Rails.logger.error("Database error detected for traffic record #{id}: #{e.message}")
      Rails.logger.error("Stack trace: #{e.backtrace.first(5).join("\n")}")
      # Mark record as having database error - don't crash the application
      begin
        update_columns(
          reward_eligible: false,
          eligibility_reason: "Database error: #{e.class.name}",
          request_source: nil
        )
      rescue => update_error
        Rails.logger.error("Failed to update traffic record after database error: #{update_error.message}")
      end
    rescue => e
      Rails.logger.error("Failed to check reward eligibility for traffic record #{id}: #{e.message}")
    end
  end
end

