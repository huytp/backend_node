class Heartbeat < ApplicationRecord
  belongs_to :node

  validates :latency, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :loss, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :bandwidth, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :uptime, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :signature, presence: true
end

