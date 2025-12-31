class MakeMerkleProofNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :rewards, :merkle_proof, true
    change_column_default :rewards, :merkle_proof, nil
  end
end

