class CreateEpochs < ActiveRecord::Migration[7.1]
  def change
    create_table :epoches do |t|
      t.integer :epoch_id, null: false, index: { unique: true }
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :merkle_root
      t.string :status, default: 'pending'
      t.float :total_traffic, default: 0
      t.integer :node_count, default: 0
      t.timestamps
    end
  end
end

