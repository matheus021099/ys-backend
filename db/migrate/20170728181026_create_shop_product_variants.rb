class CreateShopProductVariants < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_product_variants do |t|
      t.references :product, references: :shop_product
      t.references :variant, references: :shop_variant
      t.string :name
      t.integer :price, default: 100
      t.integer :quantity, default: 0

      t.string :status
      t.timestamps
    end
  end
end
