class CreateHeartbeats < ActiveRecord::Migration[7.1]
  def change
    create_table :heartbeats do |t|
      t.references :node, null: false, foreign_key: true
      t.float :latency, null: false
      t.float :loss, null: false
      t.float :bandwidth, null: false
      t.integer :uptime, null: false
      t.string :signature, null: false
      t.timestamps
    end

    add_index :heartbeats, :created_at
  end
end

