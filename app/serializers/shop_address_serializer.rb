class ShopAddressSerializer < ActiveModel::Serializer
  attributes :id, :customer_id, :email, :first_name, :last_name, :unit, :street_1, :street_2, :city, :state, :country, :postcode, :phone_number
end