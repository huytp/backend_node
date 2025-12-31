class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :name, presence: true

  before_create :generate_token

  def generate_token
    self.token = SecureRandom.hex(32)
    self.token_expires_at = 30.days.from_now
  end

  def token_valid?
    token.present? && token_expires_at.present? && token_expires_at > Time.current
  end

  def refresh_token
    generate_token
    save
  end
end

