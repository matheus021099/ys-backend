class CreateShopOrders < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_orders do |t|
      t.references :customer, references: :user
      t.references :merchant, references: :user
      t.references :cart, references: :shop_cart
      t.references :billing_address, references: :shop_address
      t.references :shipping_address, references: :shop_address
      t.boolean :enabled_address, default: true
      t.integer :amount
      t.integer :fee, default: 0
      t.integer :shipping_cost, default: 0
      t.integer :tax_cost, default: 0

      t.string :provider
      t.string :payment_customer_id
      t.string :payment_token

      t.references :payment
      t.string :ship_method
      t.string :tracking_number
      t.string :tracking_url

      t.string :status
      t.timestamps
    end
  end
end
