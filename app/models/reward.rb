class Reward < ApplicationRecord
  belongs_to :node
  belongs_to :epoch

  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :merkle_proof, presence: true
end

