class Payment < ApplicationRecord
  STREAM_HOURLY_PRICE = 1000

  enum payment_type: {
    deposit: 'deposit', # pay with credit card
    withdraw: 'withdraw',
    donate: 'donate',
    fee: 'fee',
    repost_price_upgrade_cost: 'repost_price_upgrade_cost',
    shipment: 'shipment',
    buy: 'buy',
    repost: 'repost',
    refund: 'refund',
    collaborate: 'collaborate',
    stream: 'stream',
    pay_view_stream: 'pay_view_stream'
  }

  enum status: {
    pending: 'pending',
    done: 'done'
  }

  belongs_to :sender, class_name: 'User'
  belongs_to :receiver, class_name: 'User'
  belongs_to :assoc, polymorphic: true, optional: true

  default_scope { order(created_at: :desc) }

  scope :received_by, -> receiver_id {
    where('receiver_id != sender_id AND receiver_id = ? AND payment_type NOT IN (?)', receiver_id, [
      Payment.payment_types[:deposit],
      Payment.payment_types[:withdraw],
      Payment.payment_types[:fee],
      Payment.payment_types[:shipment]
    ])
  }
  scope :sent_from, -> sender_id {
    where('receiver_id != sender_id AND sender_id = ? AND payment_type NOT IN (?)', sender_id, [
      Payment.payment_types[:deposit],
      Payment.payment_types[:withdraw],
      Payment.payment_types[:fee],
      Payment.payment_types[:shipment]
    ])
  }

  # class method
  def self.donate(sender: nil, receiver: nil, description: '', sent_amount: 0, received_amount: 0, fee: 0, payment_token: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed receiver' unless receiver.present?

    sender.update_attributes(balance_amount: sender.balance_amount - sent_amount)
    receiver.update_attributes(balance_amount: receiver.balance_amount + received_amount)

    payment = Payment.create(
      sender_id: sender.id,
      receiver_id: receiver.id,
      payment_type: Payment.payment_types[:donate],
      description: description,
      payment_token: payment_token,
      sent_amount: sent_amount,
      received_amount: received_amount,
      fee: 0,
      tax: 0,
      status: Payment.statuses[:done]
    )

    if fee > 0
      superadmin.update_attributes(balance_amount: superadmin.balance_amount + fee)

      Payment.create!(
        sender_id: sender.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:fee],
        description: description,
        payment_token: payment_token,
        sent_amount: 0,
        received_amount: fee,
        fee: 0,
        tax: 0,
        status: Payment.statuses[:done]
      )
    end

    return payment
  end

  # class method
  def self.set_repost_price(sender: nil, description: '', sent_amount: 0, payment_token: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?

    sender.update_attributes(balance_amount: sender.balance_amount - sent_amount)
    superadmin.update_attributes(balance_amount: superadmin.balance_amount + sent_amount)
    payment = Payment.create!(
      sender_id: sender.id,
      receiver_id: superadmin.id,
      payment_type: Payment.payment_types[:repost_price_upgrade_cost],
      description: description,
      payment_token: payment_token,
      sent_amount: sent_amount,
      received_amount: sent_amount,
      fee: 0,
      tax: 0,
      status: Payment.statuses[:done]
    )

    return payment
  end

  def self.send_repost_request(sender: nil, receiver: nil, sent_amount: 0, payment_token: nil, assoc_type: nil, assoc_id: nil, attachment_id: nil)

    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed receiver' unless receiver.present?

    fee = Payment.calculate_fee(sent_amount, 'repost')
    received_amount = sent_amount - fee

    sender.update_attributes(balance_amount: sender.balance_amount - sent_amount)

    payment = Payment.create(
      sender_id: sender.id,
      receiver_id: receiver.id,
      payment_type: Payment.payment_types[:repost],
      payment_token: payment_token,
      sent_amount: sent_amount,
      received_amount: received_amount,
      fee: 0,
      tax: 0,
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      attachment_id: attachment_id,
      status: Payment.statuses[:pending]
    )
    receiver.update_attributes(balance_amount: receiver.balance_amount + received_amount)

    if fee > 0
      Payment.create!(
        sender_id: sender.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:fee],
        payment_token: payment_token,
        sent_amount: 0,
        received_amount: fee,
        fee: 0,
        tax: 0,
        assoc_type: assoc_type,
        assoc_id: assoc_id,
        attachment_id: attachment_id,
        status: Payment.statuses[:pending]
      )
      superadmin.update_attributes(balance_amount: superadmin.balance_amount + fee)
    end

    payment
  end

  def self.accept_repost_request(sender: nil, receiver: nil, assoc_type: nil, assoc_id: nil, attachment_id: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed receiver' unless receiver.present?

    payments = Payment.where(
      sender_id: sender.id,
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      attachment_id: attachment_id,
      status: Payment.statuses[:pending]
    )
    return 'Not found pending payments' unless payments.size > 0

    payments.each do |payment|
      # receiver = payment.receiver
      # receiver.update_attributes(balance_amount: receiver.balance_amount + payment.received_amount)
      # case payment.payment_type
      #   when Payment.payment_types[:repost]
      #     receiver.update_attributes(balance_amount: receiver.balance_amount + payment.received_amount)
      #   when Payment.payment_types[:fee]
      #     superadmin.update_attributes(balance_amount: superadmin.balance_amount + payment.received_amount)
      # end
      payment.update_attributes(status: Payment.statuses[:done])
    end

    true
  end

  def self.deny_repost_request(assoc_type: nil, assoc_id: nil, attachment_id: nil)
    # superadmin = User.superadmin
    # return 'Not found superadmin' unless superadmin.present?
    # return 'Not passed sender' unless sender.present?
    # return 'Not passed receiver' unless receiver.present?

    payments = Payment.includes(:sender, :receiver).where(
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      attachment_id: attachment_id,
      payment_type: [ Payment.payment_types[:repost], Payment.payment_types[:fee] ],
      status: Payment.statuses[:pending]
    )
    return 'Not found pending payments' unless payments.size > 0

    payments.each do |payment|
      sender = payment.sender
      receiver = payment.receiver
      # case payment.payment_type
      #   when Payment.payment_types[:repost]
      #     receiver.update_attributes(balance_amount: receiver.balance_amount - payment.received_amount)
      #     sender.update_attributes(balance_amount: sender.balance_amount + payment.received_amount)
      #   when Payment.payment_types[:fee]
      #     superadmin.update_attributes(balance_amount: superadmin.balance_amount - payment.received_amount)
      #     sender.update_attributes(balance_amount: sender.balance_amount + payment.received_amount)
      # end
      receiver.update_attributes(balance_amount: receiver.balance_amount - payment.received_amount)
      sender.update_attributes(balance_amount: sender.balance_amount + payment.received_amount)
      payment.delete
    end

    true
  end

  def self.accept_repost_request_on_free(sender: nil, receiver: nil, assoc_type: nil, assoc_id: nil, attachment_id: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed receiver' unless receiver.present?

    payments = Payment.where(
      sender_id: sender.id,
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      attachment_id: attachment_id,
      status: Payment.statuses[:pending]
    )
    return 'Not found pending payments' unless payments.size > 0

    ### check sender.balance_amount get updated whenever whenver calling update_attributes
    # total_paid_amount = 0
    payments.each do |payment|
      case payment.payment_type
        when Payment.payment_types[:repost]
          receiver.update_attributes(balance_amount: receiver.balance_amount - payment.received_amount)
          sender.update_attributes(balance_amount: sender.balance_amount + payment.received_amount)
        when Payment.payment_types[:fee]
          superadmin.update_attributes(balance_amount: superadmin.balance_amount - payment.received_amount)
          sender.update_attributes(balance_amount: sender.balance_amount + payment.received_amount)
      end
      payment.delete
    end
    # sender.update_attributes(balance_amount: sender.balance_amount + total_paid_amount)

    true
  end

  # assoc: ShopProduct
  def self.collaborate(sender: nil, order: nil, item: nil, payment_token: nil)
    product = item.product
    total_cost = item.price * item.quantity - item.fee
    total_collaborators_amount = 0
    ActiveRecord::Base.transaction do

      Payment.create!(
        sender_id: sender.id,
        receiver_id: sender.id,
        payment_type: Payment.payment_types[:collaborate],
        payment_token: payment_token,
        sent_amount: total_cost,
        received_amount: total_cost,
        fee: 0,
        tax: 0,
        order_id: order.id,
        user_share: 100,
        assoc_type: product.class.name,
        assoc_id: product.id,
        status: Payment.statuses[:done]
      ) and return if product.collaborators_count == 0

      ### product has collaborators
      user_product = UserProduct.where(
        product_id: product.id,
        user_type: UserProduct.user_types[:creator],
        status: UserProduct.statuses[:accepted]
      ).first
      creator_share = user_product.user_share
      creator_recoup_cost = user_product.recoup_cost
      recoup_paid = true
      recoup_paid_amount = 0
      recoup_remain_amount = 0
      if creator_recoup_cost > 0
        ### user_share: 100 means paid for recoup_cost
        recoup_paid_amount = Payment.where(
          receiver_id: user_product.user_id,
          assoc_type: product.class.name,
          assoc_id: product.id,
          user_share: 100,
          status: Payment.statuses[:done]
        ).sum(:received_amount)

        if recoup_paid_amount < creator_recoup_cost
          recoup_paid = false
          recoup_remain_amount = creator_recoup_cost - recoup_paid_amount
        end
      end

      ### total_cost diminished
      if !recoup_paid
        recoup_current_amount = total_cost > recoup_remain_amount ? recoup_remain_amount : total_cost
        total_cost = total_cost > recoup_remain_amount ? total_cost - recoup_remain_amount : 0
        Payment.create!(
          sender_id: sender.id,
          receiver_id: sender.id,
          payment_type: Payment.payment_types[:collaborate],
          payment_token: payment_token,
          sent_amount: recoup_current_amount,
          received_amount: recoup_current_amount,
          fee: 0,
          tax: 0,
          order_id: order.id,
          user_share: 100,
          assoc_type: product.class.name,
          assoc_id: product.id,
          status: Payment.statuses[:done]
        ) if recoup_current_amount > 0
      end

      if recoup_paid || total_cost > 0
        user_products = UserProduct.where(
          product_id: product.id,
          user_type: UserProduct.user_types[:collaborator],
          status: UserProduct.statuses[:accepted]
        )
        user_products.each do |user_product|
          # collaborator_amount = (total_cost * user_product.user_share / 100).round
          collaborator_amount = (total_cost * user_product.user_share / 100).floor
          total_collaborators_amount += collaborator_amount

          if collaborator_amount > 0
            Payment.create!(
              sender_id: sender.id,
              receiver_id: user_product.user_id,
              payment_type: Payment.payment_types[:collaborate],
              payment_token: payment_token,
              sent_amount: collaborator_amount,
              received_amount: collaborator_amount,
              fee: 0,
              tax: 0,
              order_id: order.id,
              user_share: user_product.user_share,
              assoc_type: product.class.name,
              assoc_id: product.id,
              status: Payment.statuses[:done]
            )
            user_product.user.update_attributes(balance_amount: user_product.user.balance_amount + collaborator_amount)
          end
        end
      end

      sender.update_attributes(balance_amount: sender.balance_amount - total_collaborators_amount) if total_collaborators_amount > 0
      Payment.create!(
        sender_id: sender.id,
        receiver_id: sender.id,
        payment_type: Payment.payment_types[:collaborate],
        payment_token: payment_token,
        sent_amount: total_cost - total_collaborators_amount,
        received_amount: total_cost - total_collaborators_amount,
        fee: 0,
        tax: 0,
        order_id: order.id,
        user_share: creator_share,
        assoc_type: product.class.name,
        assoc_id: product.id,
        status: Payment.statuses[:done]
      ) if total_cost - total_collaborators_amount > 0
    end
  end

  def self.buy(sender: nil, receiver: nil, sent_amount: 0, received_amount: 0, fee: 0, shipping_cost: 0, payment_token: nil, order: nil)
    # sent_amount = received_amount + fee + shipping_cost
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed receiver' unless receiver.present?

    payment = 'Failed'
    ActiveRecord::Base.transaction do

      sender.update_attributes(balance_amount: sender.balance_amount - sent_amount)
      receiver.update_attributes(balance_amount: receiver.balance_amount + received_amount)
      payment = Payment.create!(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:buy],
        payment_token: payment_token,
        sent_amount: sent_amount,
        received_amount: received_amount,
        fee: 0,
        tax: 0,
        order_id: order.id,
        status: Payment.statuses[:done]
      )

      superadmin.update_attributes(balance_amount: superadmin.balance_amount + fee + shipping_cost) if fee + shipping_cost > 0
      Payment.create!(
        sender_id: sender.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:fee],
        payment_token: payment_token,
        sent_amount: 0,
        received_amount: fee,
        fee: 0,
        tax: 0,
        order_id: order.id,
        status: Payment.statuses[:done]
      ) if fee > 0
      Payment.create!(
        sender_id: sender.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:shipment],
        payment_token: payment_token,
        sent_amount: 0,
        received_amount: shipping_cost,
        fee: 0,
        tax: 0,
        order_id: order.id,
        status: Payment.statuses[:done]
      ) if shipping_cost > 0

      # payment records on each item
      order.items.each do |item|
        Payment.collaborate(
          sender: receiver,
          order: order,
          item: item,
          payment_token: payment_token
        )# if item.product.collaborators_count > 0
      end
    end

    payment
  end

  def self.stream(stream: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?

    stopped_at = stream.stopped_at || Time.now
    played_time = (stopped_at - stream.started_at).to_i
    played_time = stream.valid_period if played_time > stream.valid_period
    description = "#{Util::Time.humanize(played_time)} from #{stream.started_at.strftime("%H:%M:%S %b %d, %Y")}"

    amount = (STREAM_HOURLY_PRICE * played_time / 3600).to_i
    return 'Not enough period' unless amount > 0

    user = stream.user
    ActiveRecord::Base.transaction do
      payment = Payment.create!(
        sender_id: user.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:stream],
        description: description,
        payment_token: nil,
        sent_amount: amount,
        received_amount: amount,
        fee: 0,
        tax: 0,
        status: Payment.statuses[:done]
      )
      user.update_attributes!(
        balance_amount: user.balance_amount - amount,
        stream_rolled_time: stream.valid_period - played_time,
        stream_rolled_cost: (STREAM_HOURLY_PRICE * stream.valid_period / 3600).to_i - amount
      )
      superadmin.update_attributes!(balance_amount: superadmin.balance_amount + amount)
    end
  end

  def self.pay_view_stream(sender: nil, stream: nil, payment_token: nil)
    superadmin = User.superadmin
    return 'Not found superadmin' unless superadmin.present?
    return 'Not passed sender' unless sender.present?
    return 'Not passed stream' unless stream.present?
    return 'Free stream' unless stream.view_price > 0
    receiver = stream.user
    sent_amount = stream.view_price
    fee = Payment.calculate_fee(sent_amount, 'pay_view_stream')
    received_amount = sent_amount - fee

    payment = 'Failed'
    ActiveRecord::Base.transaction do
      sender.update_attributes(balance_amount: sender.balance_amount - sent_amount)
      receiver.update_attributes(balance_amount: receiver.balance_amount + received_amount)
      payment = Payment.create!(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:pay_view_stream],
        payment_token: payment_token,
        sent_amount: sent_amount,
        received_amount: received_amount,
        fee: 0,
        tax: 0,
        assoc_type: stream.class.name,
        assoc_id: stream.id,
        status: Payment.statuses[:done]
      )

      superadmin.update_attributes(balance_amount: superadmin.balance_amount + fee)
      Payment.create!(
        sender_id: sender.id,
        receiver_id: superadmin.id,
        payment_type: Payment.payment_types[:fee],
        payment_token: payment_token,
        sent_amount: 0,
        received_amount: fee,
        fee: 0,
        tax: 0,
        assoc_type: stream.class.name,
        assoc_id: stream.id,
        status: Payment.statuses[:done]
      )
    end

    payment
  end

  # refund on pay_view_stream
  def self.refund_without_fee(payment: nil, amount: 0, description: '')
    return 'Invalid amount' unless amount > 0 && amount <= payment.received_amount - payment.refund_amount
    _payment = 'Failed'
    sender = payment.sender
    receiver = payment.receiver
    ActiveRecord::Base.transaction do
      _payment = Payment.create!(
        sender_id: receiver.id,
        receiver_id: sender.id,
        payment_type: Payment.payment_types[:refund],
        description: description,
        payment_token: nil,
        sent_amount: amount,
        received_amount: amount,
        fee: 0,
        tax: 0,
        assoc_type: payment.class.name,
        assoc_id: payment.id,
        status: Payment.statuses[:done]
      )
      payment.update_attributes!(refund_amount: payment.refund_amount + amount)
      receiver.update_attributes!(balance_amount: receiver.balance_amount - amount)
      sender.update_attributes!(balance_amount: sender.balance_amount + amount)
    end
    _payment
  end

  # refund on purchase an order
  def self.refund_order(payment: nil, amount: 0, description: '', items: nil)
    return 'Invalid amount' unless amount > 0 && amount <= payment.sent_amount - payment.refund_amount
    _payment = 'Failed'
    sender = payment.sender
    receiver = payment.receiver

    ActiveRecord::Base.transaction do
      items.each do |it|
        Rails.logger.info(it)
        item = ShopItem.find(it['id'])
        _payment = Payment.create!(
          sender_id: receiver.id,
          receiver_id: sender.id,
          payment_type: Payment.payment_types[:refund],
          description: description,
          payment_token: nil,
          sent_amount: it['refund_amount'],
          received_amount: it['refund_amount'],
          fee: 0,
          tax: 0,
          order_id: payment.order_id,
          assoc_type: item.class.name,
          assoc_id: item.id,
          status: Payment.statuses[:done]
        )
        item.update_attributes!(refund_amount: it['refund_amount'], status: ShopItem.statuses[:item_refunded])
      end
      payment.update_attributes!(refund_amount: payment.refund_amount + amount, description: description)
      receiver.update_attributes!(balance_amount: receiver.balance_amount - amount)
      sender.update_attributes!(balance_amount: sender.balance_amount + amount)
    end

    _payment
  end

  # def self.deposit(user: nil, payment_token: nil, amount: 0, fee: 0, assoc_id: nil, assoc_type: nil)
  def self.deposit(user: nil, payment_token: nil, amount: 0, assoc_id: nil, assoc_type: nil)
    return 'Not passed user' unless user.present?
=begin
    # payment_account_id was used for stripe_connect_id, but customer_id for now
    stripe_customer = Stripe::Customer.retrieve(user.payment_account_id) unless user.payment_account_id.blank?
    stripe_customer = Stripe::Customer.create(email: self.email) unless stripe_customer && stripe_customer['id']
    unless stripe_customer && stripe_customer['id']
      return 'Cannot create a stripe customer'
    else
      user.update_attributes(payment_account_id: stripe_customer['id'])
    end

    stripe_source = stripe_customer.sources.create(source: payment_token)
    return 'Cannot create a stripe source with payment token' unless stripe_source['id'].blank?

    stripe_customer.default_source = stripe_source['id']
    stripe_customer.save
    stripe_charge = Stripe::Charge.create(
      amount: amount,
      currency: 'usd',
      customer: stripe_customer['id']
      # source: payment_token
    )
    return 'Stripe charge has been failed' if stripe_charge['id'].blank?
=end

    fee = Payment.stripe_fee(amount)
    stripe_charge = Stripe::Charge.create(
      amount: amount + fee,
      currency: 'usd',
      source: payment_token,
      metadata: {
        user_id: user.id,
        assoc_type: assoc_type,
        assoc_id: assoc_id
      }
    )
    return false if stripe_charge['id'].blank?

    user.update_attributes(balance_amount: user.balance_amount + amount)

    Payment.create(
      sender_id: user.id,
      receiver_id: user.id,
      payment_type: Payment.payment_types[:deposit],
      payment_token: stripe_charge['id'],
      sent_amount: 0,
      received_amount: amount,
      fee: fee,
      tax: 0,
      status: Payment.statuses[:done]
    )
    return stripe_charge['id']
  end

  def self.withdraw(user_id: nil, amount: 0)
    user = User.find_by(id: user_id)
    return 'Not found a user' unless user.present?
    return 'Not connect to stripe yet' unless user.stripe_connected?
    return 'Not enough balance' if user.available_amount < amount

    stripe_transfer = nil
    stripe_payout = nil

    begin
      stripe_transfer = Stripe::Transfer.create(
        amount: amount,
        currency: 'usd',
        destination: user.payment_account_id,
        metadata: {
          user_id: user.id,
          user_name: user.display_name
        }
      )
      return 'Stripe transfer has been failed' if stripe_transfer['id'].blank?
    rescue => ex
      return ex.message
    end

    user.update_attributes(balance_amount: user.balance_amount - amount)

    payment = Payment.create(
      sender_id: user.id,
      receiver_id: user.id,
      payment_type: Payment.payment_types[:withdraw],
      payment_token: stripe_transfer['id'],
      sent_amount: amount,
      received_amount: 0,
      fee: 0,
      tax: 0,
      status: Payment.statuses[:done]
    )

    begin
      stripe_payout = Stripe::Payout.create({
        amount: amount,
        currency: 'usd',
        # method: 'instant'
      }, {
        :stripe_account => user.payment_account_id
      })
    rescue => ex
    end

    # return "Success in Payout: #{stripe_payout['id']}"
    payment
  end

  def self.calculate_fee(amount, fee_type, fee_description = '')
    fee_percent =
      case fee_type
        when 'shopping'
          0.1
        when 'repost'
          if amount > 100
            0.1
          else
            0.5
          end
        when 'donation'
          if fee_description == 'donation'
            # 0.02
            0.1
          else
            0.1
          end
        else
          0.1
      end

    (amount * fee_percent).round
  end

  # https://memberful.com/blog/stripe-vs-paypal/
  # def self.stripe_fee(amount)
  #   (amount * 0.029 + 30).round
  # end

  def self.stripe_fee(amount)
    total = ((amount + 30) / 0.971).round
    fee1 = (total * 0.029 + 30).round
    fee = total - amount

    puts "\n\n +++++ stripe_fee +++++"
    puts "#{fee} : #{fee1}"
    puts "\n\n\n"

    fee
  end
end
