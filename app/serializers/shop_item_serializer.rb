class ShopItemSerializer < ActiveModel::Serializer
  attributes :id, :type, :price, :quantity, :fee, :shipping_cost, :tax, :tax_percent, :is_vat, :status

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