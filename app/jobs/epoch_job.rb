class EpochJob < ApplicationJob
  queue_as :default

  # Chạy mỗi 1 phút để kiểm tra và tạo epoch mới
  def perform
    begin
      # Đóng epoch cũ nếu đã hết thời gian
      EpochService.close_current_epoch

      # Đảm bảo có epoch hiện tại
      current_epoch = EpochService.get_or_create_current_epoch

      Rails.logger.debug("Current epoch: #{current_epoch.epoch_id} (ends at #{current_epoch.end_time})")
    rescue => e
      Rails.logger.error("EpochJob error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  end
end

