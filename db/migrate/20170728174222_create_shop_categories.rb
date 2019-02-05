class CreateShopCategories < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_categories do |t|
      t.string :name
      t.string :description
      t.boolean :is_digital, default: false

      t.string :status
      t.timestamps
    end
  end
end
