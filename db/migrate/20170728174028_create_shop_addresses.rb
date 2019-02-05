class CreateShopAddresses < ActiveRecord::Migration[5.0]
  def change
    create_table :shop_addresses do |t|
      t.references :customer, references: :user
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :unit
      t.string :street_1
      t.string :street_2
      t.string :city
      t.string :state
      t.string :country
      t.string :postcode
      t.string :phone_number

      t.string :status
      t.timestamps
    end
  end
end
