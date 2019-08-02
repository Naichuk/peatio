class UpdateMarketsAskFeeBidFee < ActiveRecord::Migration[5.2]
  def change
    rename_column :markets, :ask_fee, :maker_fee if column_exists?(:markets, :ask_fee)
    rename_column :markets, :bid_fee, :taker_fee if column_exists?(:markets, :bid_fee)
    rename_column :orders, :fee, :maker_fee if column_exists?(:orders, :fee)
    add_column    :orders, :taker_fee, :decimal, null: false, default: 0, precision: 32, scale: 16, after: :maker_fee 
  end
end
