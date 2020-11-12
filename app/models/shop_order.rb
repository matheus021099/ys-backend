class ShopOrder < ApplicationRecord
  # enum status: [:order_pending, :order_shipped]
  enum status: {
    order_pending: 'order_pending',
    order_shipped: 'order_shipped',
    order_refunded: 'order_refunded'
  }

  # after_create :do_after_create
  # def do_after_create
  #   ApplicationMailer.to_buyer_order_email(self).deliver
  #   ApplicationMailer.to_seller_order_email(self).deliver
  # end

  belongs_to :billing_address, class_name: 'ShopAddress'
  belongs_to :shipping_address, class_name: 'ShopAddress'
  belongs_to :customer, class_name: 'User'
  belongs_to :merchant, class_name: 'User'
  # belongs_to :payment
  has_many :payments, foreign_key: 'order_id', dependent: :destroy
  has_many :items, foreign_key: 'order_id', class_name: 'ShopItem', dependent: :destroy
  accepts_nested_attributes_for :items

  default_scope { order(created_at: :desc) }

  scope :for_product, -> (product_id) {
    joins(:items => [:product]).where(shop_products: { id: product_id })
  }

  def external_id
    Util::Number.encode self.id
  end

  def notify
    ApplicationMailer.to_buyer_order_email(self).deliver
    ApplicationMailer.to_seller_order_email(self).deliver

    message_body = "#{self.customer.display_name} purchased [#{self.items.collect{|item| item.product.name}.join(', ')}]"
    Activity.create(
      sender_id: self.customer_id,
      receiver_id: self.merchant_id,
      message: message_body,
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:order_product],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:unread]
    )
    Activity.create(
      sender_id: self.customer_id,
      receiver_id: self.customer_id,
      message: "purchased [#{self.items.collect{|item| item.product.name}.join(', ')}] from #{self.merchant.display_name}",
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:order_product],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    message_body = "[#{self.customer.display_name}] purchased [#{self.items.collect{|item| item.product.name}.join(', ')}]"
    data = {
      products: self.items.collect{|item| item.product.as_json(
        only: [ :id, :name ],
        include: {
          covers: {
            only: [ :id, :cover, :position ]
          }
        }
      )}
    }
    PushNotificationWorker.perform_async(
      self.merchant.devices.pluck(:token),
      FCMService::push_notification_types[:product_purchased],
      message_body,
      data
    )
  end
end
