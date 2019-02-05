class CreateShopItems < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_items do |t|
      t.references :customer, references: :user
      t.references :merchant, references: :user
      t.references :product, references: :shop_product
      t.references :product_variant, references: :shop_product_variant
      t.references :cart, references: :shop_cart
      t.references :order, references: :shop_order
      t.integer :price
      t.integer :quantity
      t.integer :fee, default: 0
      t.integer :shipping_cost, default: 0
      t.integer :tax, default: 0
      t.integer :tax_percent, :decimal, precision: 10, scale: 6, default: 0
      t.boolean :is_vat, default: false

      t.string :status
      t.timestamps
    end
  end
end
