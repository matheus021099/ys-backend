class CreateTickets < ActiveRecord::Migration[5.0]
  def change
    create_table :tickets do |t|
      t.references :open_user, references: :user, index: true
      t.references :close_user, references: :user, index: true
      t.string :reason
      t.text :description
      t.references :product, references: :shop_product, index: true
      t.references :item, references: :shop_item
      t.references :order, references: :shop_order
      t.datetime :closed_at
      t.string :status, default: 'open'

      t.timestamps
    end
  end
end
