class SettlementJob < ApplicationJob
  queue_as :default
  # Chạy mỗi 5 phút để settle epochs đã kết thúc
  def perform
    # Tìm epoch cần settle (epoch đã kết thúc nhưng chưa commit)
    current_time = Time.current
    epochs_to_settle = Epoch.where(status: 'pending')
                            .where('end_time <= ?', current_time)
                            .order(epoch_id: :asc)

    if epochs_to_settle.any?
      Rails.logger.info("Found #{epochs_to_settle.count} epoch(s) to settle")
    end

    epochs_to_settle.each do |epoch|
      Rails.logger.info("Settling epoch #{epoch.epoch_id} (ended at #{epoch.end_time})")
      success = SettlementService.settle_epoch(epoch.epoch_id)

      if success
        Rails.logger.info("✅ Successfully settled epoch #{epoch.epoch_id}")
      else
        Rails.logger.error("❌ Failed to settle epoch #{epoch.epoch_id}")
      end
    end
  end
end

