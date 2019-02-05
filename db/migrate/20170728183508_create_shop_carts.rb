class CreateShopCarts < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_carts do |t|
      t.references :customer, references: :users
      t.text :notes

      t.string :status
      t.timestamps
    end
  end
end
