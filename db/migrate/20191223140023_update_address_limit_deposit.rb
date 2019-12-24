class UpdateAddressLimitDeposit < ActiveRecord::Migration[5.2]
  def change
    change_column :deposits, :address, :string, limit: 106
    change_column :withdraws, :rid, :string, limit: 106
  end
end
