class AddTrackingInfoToShopItems < ActiveRecord::Migration[5.0]
  def change
    add_column :shop_items, :tracking_site, :string
    add_column :shop_items, :tracking_url, :text
    add_column :shop_items, :tracking_number, :string
  end
end
