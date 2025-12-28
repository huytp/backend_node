class AddRewardTrackingFields < ActiveRecord::Migration[7.1]
  def change
    # Thêm các trường vào traffic_records để track reward eligibility
    add_column :traffic_records, :ai_scored, :boolean, default: false
    add_column :traffic_records, :ai_score, :float
    add_column :traffic_records, :has_anomaly, :boolean, default: false
    add_column :traffic_records, :reward_eligible, :boolean, default: false
    add_column :traffic_records, :request_source, :string # 'session_end', 'epoch_end', 'performance_threshold', 'ai_confirmed'
    add_column :traffic_records, :eligibility_reason, :text

    # Thêm index cho các trường thường được query
    add_index :traffic_records, :ai_scored
    add_index :traffic_records, :reward_eligible
    add_index :traffic_records, :has_anomaly
  end
end

