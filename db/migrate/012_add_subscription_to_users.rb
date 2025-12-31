class AddSubscriptionToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :subscription_plan, :string
    add_column :users, :subscription_status, :string, default: 'inactive'
    add_column :users, :subscription_started_at, :datetime
    add_column :users, :subscription_expires_at, :datetime
    add_index :users, :subscription_status
  end
end

