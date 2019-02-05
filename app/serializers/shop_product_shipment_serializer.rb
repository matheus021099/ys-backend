class ShopProductShipmentSerializer < ActiveModel::Serializer
  attributes :id, :country, :shipment_alone_price, :shipment_with_price
end