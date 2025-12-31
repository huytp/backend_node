class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.string :token
      t.datetime :token_expires_at

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :token
  end
end

