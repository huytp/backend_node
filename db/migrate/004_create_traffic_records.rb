class CreateTrafficRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :traffic_records do |t|
      t.references :node, null: false, foreign_key: true
      t.references :vpn_connection, null: true, foreign_key: true
      t.integer :epoch_id, null: false
      t.float :traffic_mb, null: false
      t.string :signature, null: false
      t.timestamps
    end

    add_index :traffic_records, :epoch_id
    add_index :traffic_records, :created_at
  end
end

