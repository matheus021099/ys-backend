class ShopCart < ApplicationRecord
  belongs_to :customer, foreign_key: 'customer_id', class_name: 'User'

  has_many :items, -> { where status: ShopItem.statuses[:item_not_ordered] }, foreign_key: 'cart_id', class_name: 'ShopItem'
  # has_many :orders, foreign_key: 'cart_id', class_name: 'ShopOrder'

  # custom property
  def quantity
    items.sum(:quantity)
  end

  def add(pv_id, quantity = nil, page_track = nil, buyer)
    product_variant = ShopProductVariant.includes(:product).find(pv_id)
    return 'product variant is not available' unless product_variant.present?
    return 'you cannot purchase your own product' if product_variant.product.merchant_id == self.customer_id
    return 'you cannot purchase your collaborated product' if product_variant.product.user_products.where(user_id: self.customer_id).present?

    quantity ||= 1
    quantity = quantity.to_i
    item = items.where(product_variant_id: pv_id).first
    if item.present?
      unless product_variant.product.category.is_digital
        quantity = item.quantity + quantity
        modify(item.id, quantity)
      end
    else
      items.create!(
        customer_id: self.customer_id,
        merchant_id: product_variant.product.merchant_id,
        product_id: product_variant.product_id,
        product_variant_id: product_variant.id,
        price: product_variant.price,
        quantity: product_variant.product.category.is_digital ? 0 : quantity
      )
      ActionCable.server.broadcast("notification_#{self.customer_id}", {cart: 1})
    end

    Activity.create(
      sender_id: buyer.id,
      receiver_id: buyer.id,
      message: 'added to your cart',
      assoc_type: product_variant.class.name,
      assoc_id: product_variant.id,
      module_type: Activity.module_types[:cart],
      action_type: Activity.action_types[:add_to_cart],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:read]
    )

    ### for now, page_track is available for stream
    if page_track.present?
      class_name, instance_id = page_track.split(':').map(&:strip)
      if class_name.present? && instance_id.present?
        begin
          @stream = class_name.constantize.find(instance_id)
          ActionCable.server.broadcast("stream_#{@stream.id}", {carts_size: 1})
        rescue e
          Rails.logger.info(e.message)
        end
      end
    end

    return true
  end

  def modify(id, quantity = 1)
    quantity = quantity.to_i
    if quantity <= 0
      remove(id)
    else
      item = items.find(id)
      item.update_attributes(quantity: quantity)
    end
  end

  def remove(id)
    item = items.find(id)
    item.destroy
    ActionCable.server.broadcast("notification_#{self.customer_id}", {cart: -1})
  end

  def clear
    items.destroy_all
  end

  def buy(shipping_address_id, payment_token)
    shipping_address = ShopAddress.find_by(id: shipping_address_id)
    return 'You do not have shipping address' unless shipping_address.present?

    return 'Cart is empty' if items.size == 0

    items.includes(product_variant: :product).each do |item|
      unless item.product_variant.product.stock_status == 'active'
        return "#{item.product_variant.product.name} is not available"
      end

      if !item.product_variant.product.category.is_digital && item.product_variant.quantity < item.quantity
        return "#{item.product_variant.product.name} - #{item.product_variant.name} is out of stock"
      end
    end

    costs = calculate_cost(shipping_address.country, shipping_address.state)
    total_cost = costs[:total_cost]
    app_fee = Payment.calculate_fee(costs[:subtotal_cost], 'shopping')
    time = Time.now.utc
    transfer_group = "orders_at_#{time.to_i}"
    stripe_fee = Payment.stripe_fee(total_cost)
    stripe_charge = nil
    begin
      stripe_charge = Stripe::Charge.create({
        amount: total_cost + stripe_fee,
        currency: 'usd',
        source: payment_token,
        description: Payment.payment_types[:buy],
        transfer_group: transfer_group,
        metadata: {
          payment_type: Payment.payment_types[:buy],
          sender: customer.username,
          amount: total_cost,
          orders_at: time
        },
      })
    rescue => ex
      return ex.message
    end
    # return 'Price has been changed' if stripe_charge['id'].blank?
    # return 'Stripe operation failed' if stripe_charge['id'].blank?

    orders = []
    items_count = items.size
    ActiveRecord::Base.transaction do
      items.select('shop_items.merchant_id').group('shop_items.merchant_id').map(&:merchant_id).each do |merchant_id|
        merchant = User.find(merchant_id)
        order = ShopOrder.new

        subtotal = 0
        shipping = 0
        tax_cost = 0
        items.includes(product_variant: :product).where(merchant_id: merchant_id).each do |item|
          item_cost = 0
          item_shipping_price = 0
          item_tax = 0
          item_tax_percent = 0

          if item.product_variant.product.category.is_digital
            item_cost = item.product_variant.price
            subtotal += item_cost
          else
            item_shipping_price = item.product_variant.product.shipping_price_for_location(items_count, shipping_address.country)
            item_cost = item.product_variant.price * item.quantity
            item_shipping_cost = item_shipping_price * item.quantity
            shipping += item_shipping_cost
            subtotal += item_cost
            item_tax_percent = item.product_variant.product.tax_percent_for_location(shipping_address.country, shipping_address.state)
            item_tax = ((item_cost + item_shipping_cost) * item_tax_percent / 100).to_i
            tax_cost += item_tax
          end

          item.attributes = {
            price: item.product_variant.price,
            shipping_cost: item_shipping_price,
            fee: Payment.calculate_fee(item_cost, 'shopping'),
            tax: item_tax,
            tax_percent: item_tax_percent,
            is_vat: item.product_variant.product.is_vat,
            status: ShopItem.statuses[:item_ordered]
          }

          if item.product_variant.product.category.is_digital
            item.status = ShopItem.statuses[:item_shipped]
          else
            item.product_variant.quantity -= item.quantity
            item.product_variant.save!

            if item.product_variant.quantity == 0 && item.product.stock == 0
              item.product.stock_status = ShopProduct.stock_statuses[:hidden]
              item.product.save!
            end
          end

          order.items << item
        end

        total_cost = subtotal + shipping + tax_cost
        app_fee = Payment.calculate_fee(subtotal, 'shopping')
        order.attributes = {
          cart_id: self.id,
          customer_id: self.customer_id,
          merchant_id: merchant_id,
          billing_address_id: shipping_address.id,
          shipping_address_id: shipping_address.id,
          amount: subtotal,
          payment_fee: Payment.stripe_fee(subtotal),
          fee: app_fee,
          tax_cost: tax_cost,
          shipping_cost: shipping,
          provider: nil,
          payment_token: payment_token,
          status: ShopOrder.statuses[:order_pending]
        }
        if order.items.select{ |item| item.status != 'item_shipped' }.blank?
          order.status = ShopOrder.statuses[:order_shipped]
        end
        # order.merchant = merchant
        order.save!

        payment = Payment.buy(
          sender: customer,
          receiver: merchant,
          sent_amount: total_cost,
          received_amount: total_cost - app_fee,
          fee: app_fee,
          # shipping_cost: shipping,
          shipping_cost: 0,
          payment_token: stripe_charge['id'],
          transfer_group: transfer_group,
          order: order
        )

        unless payment.instance_of? Payment
          # Rails.logger.info 'raise rollback'
          # puts "\t\traise rollback\t\t"
          raise ActiveRecord::Rollback

          stripe_refund = Stripe::Refund.create({
            charge: stripe_charge['id'],
          })
          # return 'Stripe operation failed' if stripe_refund['id'].blank?
          return payment
        else
          orders << order
        end
      end
    end

    orders.each do |order|
      message_body = "#{self.customer.display_name} purchased [#{order.items.collect{|item| item.product.name}.join(', ')}]"
      Activity.create(
        sender_id: self.customer_id,
        receiver_id: order.merchant_id,
        message: message_body,
        assoc_type: order.class.name,
        assoc_id: order.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:order_product],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread]
      )
      Activity.create(
        sender_id: self.customer_id,
        receiver_id: self.customer_id,
        message: "purchased [#{order.items.collect{|item| item.product.name}.join(', ')}] from #{order.merchant.display_name}",
        assoc_type: order.class.name,
        assoc_id: order.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:order_product],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:read]
      )

      ActionCable.server.broadcast("notification_#{order.merchant_id}", {sell: 1})
      order.items.each do |item|
        item.mark_as_shipped if item.product.category.is_digital
      end

      message_body = "[#{self.customer.display_name}] purchased [#{order.items.collect{|item| item.product.name}.join(', ')}]"

      data = {
        products: order.items.collect{|item| item.product.as_json(
          only: [ :id, :name ],
          include: {
            covers: {
              only: [ :id, :cover, :position ]
            }
          }
        )}
      }

      PushNotificationWorker.perform_async(
        order.merchant.devices.where(enabled: true).pluck(:token),
        FCMService::push_notification_types[:product_purchased],
        message_body,
        data
      )
    end

    ActionCable.server.broadcast("notification_#{self.customer_id}", {cart: -items_count})
    orders
  end

  def calculate_cost(country, state = '')
    total_cost = 0
    shipping_cost = 0
    subtotal_cost = 0
    tax_cost = 0
    items_count = items.size
    items.select('shop_items.merchant_id').group('shop_items.merchant_id').map(&:merchant_id).each do |merchant_id|
      merchant = User.find(merchant_id)
      items.includes(product_variant: :product).where(merchant_id: merchant_id).each do |item|
        if item.product_variant.product.category.is_digital
          item_cost = item.product_variant.price
          subtotal_cost += item_cost
        else
          item_cost = item.product_variant.price * item.quantity
          item_shipping_price = item.product_variant.product.shipping_price_for_location(items_count, country)
          item_shipping_cost = item_shipping_price * item.quantity
          shipping_cost += item_shipping_cost
          subtotal_cost += item_cost
          item_tax_percent = item.product_variant.product.tax_percent_for_location(country, state)
          tax_cost += ((item_cost + item_shipping_cost) *  item_tax_percent / 100).to_i
        end
      end
    end
    total_cost = subtotal_cost + shipping_cost + tax_cost

    return {
      total_cost: total_cost,
      subtotal_cost: subtotal_cost,
      shipping_cost: shipping_cost,
      tax_cost: tax_cost,
      fee_cost: Payment.stripe_fee(total_cost)
    }
  end
end
