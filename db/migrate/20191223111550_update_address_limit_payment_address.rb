class UpdateAddressLimitPaymentAddress < ActiveRecord::Migration[5.2]
  def change
    change_column :payment_addresses, :address, :string, limit: 106
  end
end
