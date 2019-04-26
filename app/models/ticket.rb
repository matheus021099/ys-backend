class Ticket < ApplicationRecord
  enum status: {
    open: 'open',
    close: 'close'
  }

  belongs_to :open_user, foreign_key: 'open_user_id', class_name: 'User'
  belongs_to :close_user, foreign_key: 'close_user_id', class_name: 'User'
  belongs_to :product, foreign_key: 'product_id', class_name: 'ShopProduct'
  belongs_to :item, foreign_key: 'item_id', class_name: 'ShopItem'
  belongs_to :order, foreign_key: 'order_id', class_name: 'ShopOrder'
end
