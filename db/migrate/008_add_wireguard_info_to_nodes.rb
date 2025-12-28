class AddWireguardInfoToNodes < ActiveRecord::Migration[7.1]
  def change
    add_column :nodes, :wireguard_public_key, :string
    add_column :nodes, :wireguard_endpoint, :string
    add_column :nodes, :wireguard_listen_port, :integer
    add_column :nodes, :node_api_url, :string
  end
end

