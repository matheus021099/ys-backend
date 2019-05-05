class ShopItem < ApplicationRecord
  # enum status: [:item_not_ordered, :item_ordered, :item_shipped]
  enum status: {
    item_not_ordered: 'item_not_ordered',
    item_ordered: 'item_ordered',
    item_shipped: 'item_shipped'
  }

  belongs_to :merchant, class_name: 'User'
  belongs_to :customer, class_name: 'User'
  belongs_to :product, class_name: 'ShopProduct'
  belongs_to :product_variant, class_name: 'ShopProductVariant'
  belongs_to :cart, class_name: 'ShopCart'
  belongs_to :order, class_name: 'ShopOrder'

  # scope :unordered, -> { where('order_id IS NULL') }
  scope :not_ordered, -> { where(status: ShopItem.statuses[:item_not_ordered]) }
  scope :ordered, -> { where.not(status: ShopItem.statuses[:item_not_ordered]) }

  def subtotal_cost
    # to calculate the cost of digital product
    q = quantity
    q = 1 if q < 1
    price * q
  end

  def total_cost
    (price + shipping_cost) * quantity
  end

  def mark_as_shipped
    self.update_attributes(status: ShopItem.statuses[:item_shipped])
    if self.order.items.where(status: ShopItem.statuses[:item_ordered]).size == 0
      self.order.update_attributes(status: ShopOrder.statuses[:order_shipped])
    end
    ActionCable.server.broadcast("notification_#{self.merchant_id}", {sell: -1})
  end
end
