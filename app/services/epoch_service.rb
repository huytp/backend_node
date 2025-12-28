class EpochService
  # Epoch duration: 5 phút (theo smart contract)
  EPOCH_DURATION = 5.minutes

  # Tạo epoch mới hoặc lấy epoch hiện tại
  def self.get_or_create_current_epoch
    # Tìm epoch hiện tại (pending hoặc processing)
    current_epoch = Epoch.where(status: ['pending', 'processing'])
                        .order(epoch_id: :desc)
                        .first

    # Nếu có epoch hiện tại và chưa hết thời gian
    if current_epoch && current_epoch.end_time > Time.current
      return current_epoch
    end

    # Nếu epoch hiện tại đã hết thời gian, tạo epoch mới
    create_new_epoch
  end

  # Tạo epoch mới
  def self.create_new_epoch
    # Lấy epoch_id tiếp theo
    last_epoch = Epoch.order(epoch_id: :desc).first
    next_epoch_id = last_epoch ? last_epoch.epoch_id + 1 : 1

    # Tính thời gian
    start_time = Time.current
    end_time = start_time + EPOCH_DURATION

    # Tạo epoch mới
    epoch = Epoch.create!(
      epoch_id: next_epoch_id,
      start_time: start_time,
      end_time: end_time,
      status: 'pending'
    )

    Rails.logger.info("Created new epoch: #{epoch.epoch_id} (#{start_time} - #{end_time})")
    epoch
  end

  # Đóng epoch hiện tại (chuyển sang pending để settle)
  def self.close_current_epoch
    current_epoch = Epoch.where(status: ['pending', 'processing'])
                        .where('end_time <= ?', Time.current)
                        .order(epoch_id: :desc)
                        .first

    return nil unless current_epoch

    # Cập nhật end_time nếu cần
    if current_epoch.end_time > Time.current
      current_epoch.update!(end_time: Time.current)
    end

    Rails.logger.info("Closed epoch: #{current_epoch.epoch_id}")
    current_epoch
  end

  # Lấy epoch hiện tại (không tạo mới)
  def self.current_epoch
    Epoch.where(status: ['pending', 'processing'])
         .where('end_time > ?', Time.current)
         .order(epoch_id: :desc)
         .first
  end

  # Lấy epoch_id hiện tại
  def self.current_epoch_id
    epoch = current_epoch
    return epoch.epoch_id if epoch

    # Nếu không có epoch hiện tại, lấy epoch_id mới nhất
    last_epoch = Epoch.order(epoch_id: :desc).first
    last_epoch ? last_epoch.epoch_id + 1 : 1
  end
end

