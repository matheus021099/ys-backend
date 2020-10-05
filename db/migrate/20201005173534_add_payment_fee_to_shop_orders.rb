class AddPaymentFeeToShopOrders < ActiveRecord::Migration[5.0]
  def change
    add_column :shop_orders, :payment_fee, :integer, default: 0
  end
end
