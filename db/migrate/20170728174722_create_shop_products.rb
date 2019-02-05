class CreateShopProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_products do |t|
      t.references :merchant, references: :user
      t.references :category, references: :shop_category
      t.string :name
      t.string :description
      t.integer :position, default: 0
      t.integer :price
      t.decimal :weight
      t.decimal :height
      t.decimal :width
      t.decimal :depth

      t.string :digital_content
      t.string :digital_content_name

      t.boolean :is_vat, default: false
      t.decimal :tax_percent, precision: 10, scale: 6, default: 0
      t.string  :seller_location

      t.integer :reposted, default: 0
      t.integer :sold, default: 0
      t.integer :quantity, default: 0
      t.integer :collaborators_count, default: 0

      t.boolean :released, default: false
      t.datetime  :released_at

      t.string  :stock_status, default: 'active'
      t.string  :show_status, default: 'show_all'

      t.string :status
      t.timestamps
    end
  end
end
