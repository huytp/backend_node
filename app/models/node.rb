class Node < ApplicationRecord
  validates :address, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[active inactive disabled] }

  has_many :heartbeats, dependent: :destroy
  has_many :traffic_records, dependent: :destroy
  has_many :rewards, dependent: :destroy

  enum status: {
    active: 'active',
    inactive: 'inactive',
    disabled: 'disabled'
  }

  scope :active_nodes, -> { where(status: 'active') }

  def update_from_heartbeat(heartbeat_data)
    update!(
      latency: heartbeat_data[:latency],
      loss: heartbeat_data[:loss],
      bandwidth: heartbeat_data[:bandwidth],
      uptime: heartbeat_data[:uptime],
      last_heartbeat_at: Time.current,
      status: :active
    )
  end

  def calculate_quality_score
    # Quality = f(latency, loss, uptime)
    latency_score = [100 - (latency || 1000) / 10, 0].max
    loss_score = [100 - (loss || 1) * 1000, 0].max
    uptime_score = [(uptime || 0) / 360, 100].min

    (latency_score * 0.4 + loss_score * 0.4 + uptime_score * 0.2).round(2)
  end
end

