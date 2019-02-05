class ShopProductCover < ApplicationRecord
  mount_uploader :cover, CoverUploader

  belongs_to :product, class_name: 'ShopProduct'
end
