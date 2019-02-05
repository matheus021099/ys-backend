class CreateShopProductShipments < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_product_shipments do |t|
      t.references :product, references: :shop_product
      t.string :country
      t.integer :shipment_alone_price
      t.integer :shipment_with_price

      t.string :status
      t.timestamps
    end
  end
end
