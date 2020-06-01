class AddRefundAmountToShopItems < ActiveRecord::Migration[5.0]
  def change
    add_column :shop_items, :refund_amount, :integer, default: 0
    add_column :shop_items, :description, :string, default: ''
  end
end
