class AddWireguardPrivateKeyToNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :nodes, :wireguard_private_key, :string
  end
end

