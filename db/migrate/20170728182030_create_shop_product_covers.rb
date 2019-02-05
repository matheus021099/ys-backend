class CreateShopProductCovers < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_product_covers do |t|
      t.references :product, references: :shop_product
      t.string :cover
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
