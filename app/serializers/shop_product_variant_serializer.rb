class ShopProductVariantSerializer < ActiveModel::Serializer
  attributes :id, :name, :price, :quantity
end