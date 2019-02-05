class CreateShopVariants < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_variants do |t|
      t.string :name
      t.text "options_json"

      t.timestamps
    end
  end
end
