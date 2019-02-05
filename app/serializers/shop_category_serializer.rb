class ShopCategorySerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :is_digital
end