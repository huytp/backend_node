class CreateRewards < ActiveRecord::Migration[7.1]
  def change
    create_table :rewards do |t|
      t.references :node, null: false, foreign_key: true
      t.references :epoch, null: false, foreign_key: true
      t.integer :amount, null: false
      t.text :merkle_proof, null: false
      t.boolean :claimed, default: false
      t.timestamps
    end

    add_index :rewards, [:node_id, :epoch_id], unique: true
  end
end

