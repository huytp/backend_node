class CreateNodes < ActiveRecord::Migration[7.1]
  def change
    create_table :nodes do |t|
      t.string :address, null: false, index: { unique: true }
      t.string :status, default: 'inactive'
      t.float :latency
      t.float :loss
      t.float :bandwidth
      t.integer :uptime
      t.integer :reputation_score
      t.datetime :last_heartbeat_at
      t.timestamps
    end
  end
end

