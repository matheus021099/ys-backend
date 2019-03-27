class ShopItemSerializer < ActiveModel::Serializer
  attributes  :id, :price, :quantity, :fee, :shipping_cost, :tax, :tax_percent, :is_vat, :status,
              :tracking_site, :tracking_url, :tracking_number

  # belongs_to :product, class_name: 'ShopProduct'
  attribute :product
  attribute :product_variant

  def product
    ShopProductSerializer.new(object.product, scope: scope, include_collaborators: true)
  end

  def product_variant
    ShopProductVariantSerializer.new(object.product_variant, scope: scope)
  end
end