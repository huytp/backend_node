class CreateVpnConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :vpn_connections do |t|
      t.string :connection_id, null: false, index: { unique: true }
      t.string :user_address, null: false
      t.references :entry_node, null: false, foreign_key: { to_table: :nodes }
      t.references :exit_node, null: false, foreign_key: { to_table: :nodes }
      t.string :status, default: 'connected'
      t.float :route_score
      t.timestamps
    end
  end
end

