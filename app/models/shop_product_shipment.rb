class ShopProductShipment < ApplicationRecord
  belongs_to :product, class_name: 'ShopProduct'
end
