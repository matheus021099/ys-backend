class Payment < ApplicationRecord
  STREAM_HOURLY_PRICE = 1000

  enum payment_type: {
    deposit: 'deposit', # pay with credit card
    withdraw: 'withdraw',
    donate: 'donate',
    video_credit: 'video_credit',
    fee: 'fee',
    repost_price_upgrade_cost: 'repost_price_upgrade_cost',
    shipment: 'shipment',
    buy: 'buy',
    repost: 'repost',
    refund: 'refund',
    recoup: 'recoup',
    collaborate: 'collaborate',
    stream: 'stream',
    stream_collaborate: 'stream_collaborate',
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

  class << self
    def donate(sender: nil, receiver: nil, description: '', sent_amount: 0, payment_token: nil)
      precheck = Payment.precheck([sender], [receiver], payment_token)
      return precheck unless precheck === true

      app_fee = Payment.calculate_fee(sent_amount, 'donation', description.downcase)
      received_amount = sent_amount - app_fee
      stripe_fee = Payment.stripe_fee(sent_amount)
      stripe_charge = Stripe::Charge.create({
        amount: sent_amount + stripe_fee,
        application_fee_amount: app_fee,
        currency: 'usd',
        source: payment_token,
        description: Payment.payment_types[:donate],
        metadata: {
          payment_type: Payment.payment_types[:donate],
          sender: sender.username,
          amount: sent_amount
        },
      }, {
        stripe_account: receiver.payment_account_id
      })# rescue {}
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      Payment.create(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:donate],
        description: description,
        payment_token: stripe_charge['id'],
        sent_amount: sent_amount,
        received_amount: received_amount,
        payment_fee: stripe_fee,
        fee: app_fee,
        tax: 0,
        status: Payment.statuses[:done]
      )
    end

    def video_credit(sender: nil, receiver: nil, description: '', sent_amount: 0, payment_token: nil)
      precheck = Payment.precheck([sender, receiver], [], payment_token)
      return precheck unless precheck === true

      app_fee = Payment.calculate_fee(sent_amount, 'donation', description.downcase)
      received_amount = sent_amount - app_fee
      stripe_fee = Payment.stripe_fee(sent_amount)
      stripe_charge = Stripe::Charge.create({
        amount: sent_amount + stripe_fee,
        currency: 'usd',
        source: payment_token,
        description: Payment.payment_types[:video_credit],
        metadata: {
          payment_type: Payment.payment_types[:video_credit],
          sender: sender.username,
          receiver: receiver.username,
          amount: sent_amount
        },
      })
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      receiver.update_columns(
        stream_rolled_cost: receiver.stream_rolled_cost + received_amount
      )

      if receiver.stream
        receiver.stream.checkpoint
      end

      Payment.create(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:video_credit],
        description: description,
        payment_token: stripe_charge['id'],
        sent_amount: sent_amount,
        received_amount: received_amount,
        payment_fee: stripe_fee,
        fee: app_fee,
        tax: 0,
        status: Payment.statuses[:done]
      )
    end

    def upgrade_repost_price(sender: nil, description: '', sent_amount: 0, payment_token: nil)
      receiver = User.public_relations_user
      precheck = Payment.precheck([sender, receiver], [], payment_token)
      return precheck unless precheck === true

      stripe_fee = Payment.stripe_fee(sent_amount)
      stripe_charge = Stripe::Charge.create({
        amount: sent_amount + stripe_fee,
        currency: 'usd',
        source: payment_token,
        # application_fee_amount: sent_amount,
        description: Payment.payment_types[:repost_price_upgrade_cost],
        metadata: {
          payment_type: Payment.payment_types[:repost_price_upgrade_cost],
          sender: sender.username
        }
      })
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      Payment.create!(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:repost_price_upgrade_cost],
        description: description,
        payment_token: stripe_charge['id'],
        sent_amount: sent_amount,
        received_amount: sent_amount,
        payment_fee: stripe_fee,
        fee: 0,
        tax: 0,
        status: Payment.statuses[:done]
      )
    end

    def send_repost_request(sender: nil, receiver: nil, attachment: nil, sent_amount: 0, payment_token: nil)
      precheck = Payment.precheck([sender, attachment], [], payment_token)
      return precheck unless precheck === true

      app_fee = Payment.calculate_fee(sent_amount, 'repost')
      received_amount = sent_amount - app_fee

      stripe_fee = Payment.stripe_fee(sent_amount)
      stripe_charge = Stripe::Charge.create({
        amount: sent_amount + stripe_fee,
        currency: 'usd',
        source: payment_token,
        application_fee_amount: app_fee,
        description: Payment.payment_types[:repost],
        metadata: {
          payment_type: Payment.payment_types[:repost],
          sender: sender.username,
          receiver: receiver.username,
          amount: sent_amount,
          attachment: attachment.id,
          attachable_type: attachment.attachable_type,
          attachable_id: attachment.attachable_id,
          attachable_name: attachment.attachable.name
        },
        capture: false
      }, {
        stripe_account: receiver.payment_account_id
      })
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      Payment.create(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:repost],
        payment_token: stripe_charge['id'],
        sent_amount: sent_amount,
        received_amount: received_amount,
        payment_fee: stripe_fee,
        fee: app_fee,
        tax: 0,
        assoc_type: attachment.attachable_type,
        assoc_id: attachment.attachable_id,
        attachment_id: attachment.id,
        status: Payment.statuses[:pending]
      )
    end

    def accept_repost_request(attachment: nil)
      payment = Payment.includes(:sender, :receiver).find_by(attachment_id: attachment.id) rescue nil
      return 'Pending payment not found' unless payment.present?

      sender = payment.sender
      receiver = payment.receiver
      precheck = Payment.precheck([sender, attachment], [receiver], payment.payment_token)
      return precheck unless precheck === true

      # stripe_transfer = Stripe::Transfer.create(
      #   amount: payment.received_amount,
      #   currency: 'usd',
      #   destination: receiver.payment_account_id,
      #   metadata: {
      #     payment_type: Payment.payment_types[:repost],
      #     amount: payment.sent_amount,
      #     sender: sender.username,
      #     receiver: receiver.username
      #   }
      # )
      # return 'Stripe operation failed' if stripe_transfer['id'].blank?

      stripe_charge = Stripe::Charge.capture(
        payment.payment_token, {}, {
          stripe_account: receiver.payment_account_id
        }
      )
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      payment.update_attributes(
        payment_token: stripe_charge['id'],
        status: Payment.statuses[:done]
      )
    end

    def deny_repost_request(attachment: nil)
      payment = Payment.includes(:sender, :receiver).find_by(attachment_id: attachment.id) rescue nil
      return true unless payment.present? && payment.receiver.stripe_connected

      stripe_refund = Stripe::Refund.create({
        charge: payment.payment_token,
      }, {
        stripe_account: payment.receiver.payment_account_id
      })
      return 'Stripe operation failed' if stripe_refund['id'].blank?

      payment.destroy
      true
    end

    def accept_repost_request_on_free(attachment: nil)
      Payment.deny_repost_request(attachment: attachment)
    end

    def buy(sender: nil, receiver: nil, order: nil, sent_amount: 0, received_amount: 0, fee: 0, shipping_cost: 0, payment_token: nil, transfer_group: nil)
      precheck = Payment.precheck([sender], [receiver], payment_token)
      return precheck unless precheck === true

      stripe_fee = Payment.stripe_fee(sent_amount)
      # transfer_group = "order_#{order.external_id}"
      # stripe_transfer = Stripe::Transfer.create({
      #   amount: sent_amount,
      #   currency: 'usd',
      #   destination: receiver.payment_account_id,
      #   description: Payment.payment_types[:buy],
      #   transfer_group: transfer_group,
      #   metadata: {
      #     payment_type: Payment.payment_types[:buy],
      #     sender: sender.username,
      #     amount: sent_amount,
      #     order: order.external_id
      #   },
      # })
      # return 'Stripe operation failed' if stripe_transfer['id'].blank?

      shared_amount = 0
      order.items.each do |item|
        shared_amount += Payment.collaborate(
          sender: sender,
          receiver: receiver,
          order: order,
          item: item,
          transfer_group: transfer_group,
          payment_token: payment_token
        )
      end

      if shared_amount < received_amount
        stripe_transfer = Stripe::Transfer.create({
          amount: received_amount - shared_amount,
          currency: 'usd',
          source_transaction: payment_token,
          destination: receiver.payment_account_id,
          description: Payment.payment_types[:buy],
          transfer_group: transfer_group,
          metadata: {
            payment_type: Payment.payment_types[:buy],
            sender: sender.username,
            amount: sent_amount,
            order: order.external_id
          },
        })
        return 'Stripe operation failed' if stripe_transfer['id'].blank?
      end

      Payment.create(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:buy],
        payment_token: payment_token,
        sent_amount: sent_amount,
        received_amount: received_amount,
        # received_amount: received_amount - shared_amount,
        payment_fee: stripe_fee,
        fee: fee,
        tax: 0,
        order_id: order.id,
        status: Payment.statuses[:done]
      )
    end

    def collaborate(sender: nil, receiver: nil, order: nil, item: nil, transfer_group: nil, payment_token: nil)
      product = item.product
      item_total_cost = item.price * item.quantity# - item.fee
      item_shared_amount = 0

      if product.collaborators_count > 0
        #TODO add recoup_paid column to UserProduct
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
        recoup_current_amount = 0
        ### user_product.user is receiver, product merchant, but make sure he connect to stripe
        if user_product.user.stripe_connected && creator_recoup_cost > 0
          ### user_share: 100 means paid for recoup_cost
          recoup_paid_amount = Payment.where(
            payment_type: Payment.payment_types[:recoup],
            receiver_id: user_product.user_id,
            assoc_type: product.class.name,
            assoc_id: product.id,
            status: Payment.statuses[:done]
          ).sum(:received_amount)

          if recoup_paid_amount < creator_recoup_cost
            recoup_paid = false
            recoup_remain_amount = creator_recoup_cost - recoup_paid_amount
          end

          ### item_total_cost diminished
          if !recoup_paid
            recoup_current_amount = item_total_cost > recoup_remain_amount ? recoup_remain_amount : item_total_cost
            recoup_remain_amount -= recoup_current_amount
            item_total_cost -= recoup_current_amount
            item_shared_amount += recoup_current_amount

            if recoup_current_amount > 0
              stripe_transfer = Stripe::Transfer.create({
                amount: recoup_current_amount,
                currency: 'usd',
                source_transaction: payment_token,
                destination: user_product.user.payment_account_id,
                description: Payment.payment_types[:recoup],
                transfer_group: transfer_group,
                metadata: {
                  payment_type: Payment.payment_types[:recoup],
                  product: product.name,
                  recoup_remain_amount: recoup_remain_amount,
                  order: order.external_id,
                }
              })
              return 'Stripe operation failed' if stripe_transfer['id'].blank?

              Payment.create(
                sender_id: sender.id,
                receiver_id: user_product.user.id,
                payment_type: Payment.payment_types[:recoup],
                payment_token: stripe_transfer['id'],
                sent_amount: recoup_current_amount,
                received_amount: recoup_current_amount,
                payment_fee: 0,
                fee: 0,
                tax: 0,
                order_id: order.id,
                assoc_type: product.class.name,
                assoc_id: product.id,
                status: Payment.statuses[:done]
              )
            end
          end
        end

        if item_total_cost > 0
          user_products = UserProduct.where(
            product_id: product.id,
            user_type: UserProduct.user_types[:collaborator],
            status: UserProduct.statuses[:accepted]
          )
          user_products.each do |user_product|
            ### cannot share the amount because collaborate did not connect to stripe
            next unless user_product.user.stripe_connected

            collaborator_amount = (item_total_cost * user_product.user_share / 100).floor

            if collaborator_amount > 0
              stripe_transfer = Stripe::Transfer.create({
                amount: collaborator_amount,
                currency: 'usd',
                source_transaction: payment_token,
                destination: user_product.user.payment_account_id,
                description: Payment.payment_types[:collaborate],
                transfer_group: transfer_group,
                metadata: {
                  payment_type: Payment.payment_types[:collaborate],
                  product: product.name,
                  order: order.external_id,
                }
              })
              next if stripe_transfer['id'].blank?

              Payment.create(
                sender_id: sender.id,
                receiver_id: user_product.user_id,
                payment_type: Payment.payment_types[:collaborate],
                payment_token: stripe_transfer['id'],
                sent_amount: collaborator_amount,
                received_amount: collaborator_amount,
                payment_fee: 0,
                fee: 0,
                tax: 0,
                order_id: order.id,
                user_share: user_product.user_share,
                assoc_type: product.class.name,
                assoc_id: product.id,
                status: Payment.statuses[:done]
              )

              item_shared_amount += collaborator_amount
            end
          end
        end
      end

      item_shared_amount
    end

    def stream_deposit(sender: nil, payment_token: nil, sent_amount: 0, assoc_id: nil, assoc_type: nil)
      receiver = User.public_relations_user
      precheck = Payment.precheck([receiver], [sender], payment_token)
      return precheck unless precheck === true

      stripe_fee = Payment.stripe_fee(sent_amount)
      stripe_charge = Stripe::Charge.create(
        amount: sent_amount + stripe_fee,
        currency: 'usd',
        source: payment_token,
        # application_fee_amount: sent_amount,
        description: Payment.payment_types[:stream],
        metadata: {
          payment_type: Payment.payment_types[:stream],
          sender: sender.username,
        }
      )
      return 'Stripe operation failed' if stripe_charge['id'].blank?

      sender.update_columns(stream_rolled_cost: sender.stream_rolled_cost + sent_amount)

      if sender.stream
        sender.stream.checkpoint
      end

      Payment.create(
        sender_id: sender.id,
        receiver_id: receiver.id,
        payment_type: Payment.payment_types[:stream],
        payment_token: stripe_charge['id'],
        sent_amount: sent_amount,
        received_amount: 0,
        payment_fee: stripe_fee,
        fee: sent_amount,
        tax: 0,
        status: Payment.statuses[:done]
      )
    end

    def pay_stream(stream: nil)
      precheck = Payment.precheck([stream, stream.user], [], true)
      return precheck unless precheck === true

      user = stream.user
      stream_rolled_cost = user.stream_rolled_cost > stream.cost ? user.stream_rolled_cost - stream.cost : 0
      user.update_columns(
        stream_rolled_cost: stream_rolled_cost
      )

      true
    end

    # def pay_view_stream(sender: nil, stream: nil, payment_token: nil)
    #   precheck = Payment.precheck([sender, stream], [stream.user], payment_token)
    #   return 'Free live video' unless stream.view_price > 0
    #   receiver = stream.user
    #   sent_amount = stream.view_price
    #   app_fee = Payment.calculate_fee(sent_amount, 'pay_view_stream')
    #   received_amount = sent_amount - app_fee
    #   stripe_fee = Payment.stripe_fee(sent_amount)
    #   stripe_charge = Stripe::Charge.create({
    #     amount: sent_amount + stripe_fee,
    #     application_fee_amount: app_fee,
    #     currency: 'usd',
    #     source: payment_token,
    #     description: Payment.payment_types[:pay_view_stream],
    #     metadata: {
    #       payment_type: Payment.payment_types[:pay_view_stream],
    #       sender: sender.username,
    #       stream: stream.name,
    #       stream_id: stream.id,
    #       amount: sent_amount
    #     },
    #   }, {
    #     stripe_account: receiver.payment_account_id
    #   })
    #   return 'Stripe operation failed' if stripe_charge['id'].blank?
    #   Payment.create(
    #     sender_id: sender.id,
    #     receiver_id: receiver.id,
    #     payment_type: Payment.payment_types[:pay_view_stream],
    #     payment_token: stripe_charge['id'],
    #     sent_amount: sent_amount,
    #     received_amount: received_amount,
    #     payment_fee: stripe_fee,
    #     fee: 0,
    #     tax: 0,
    #     assoc_type: stream.class.name,
    #     assoc_id: stream.id,
    #     status: Payment.statuses[:done]
    #   )
    # end

    def pay_view_stream(sender: nil, stream: nil, payment_token: nil)
      precheck = Payment.precheck([sender, stream], [stream.user], payment_token)
      return 'Free live video' unless stream.view_price > 0

      receiver = stream.user
      sent_amount = stream.view_price
      app_fee = Payment.calculate_fee(sent_amount, 'pay_view_stream')
      received_amount = sent_amount - app_fee
      stripe_fee = Payment.stripe_fee(sent_amount)

      transfer_group = "#{stream.id}_#{sender.username}_#{Time.now.utc.to_i}"
      stripe_charge = Stripe::Charge.create({
        amount: sent_amount + stripe_fee,
        currency: 'usd',
        source: payment_token,
        description: Payment.payment_types[:pay_view_stream],
        transfer_group: transfer_group,
        metadata: {
          payment_type: Payment.payment_types[:pay_view_stream],
          sender: sender.username,
          stream: stream.name,
          stream_id: stream.id,
          amount: sent_amount
        },
      })
      return 'Stripe operation failed' if stripe_charge['id'].blank?
      stripe_charge_id = stripe_charge['id']

      shared_amount = Payment.view_stream_collaborate(
        sender: sender,
        stream: stream,
        paid_amount: received_amount,
        transfer_group: transfer_group,
        payment_token: stripe_charge_id
      )

      if shared_amount < received_amount
        stripe_transfer = Stripe::Transfer.create({
          amount: received_amount - shared_amount,
          currency: 'usd',
          source_transaction: stripe_charge_id,
          destination: receiver.payment_account_id,
          description: Payment.payment_types[:pay_view_stream],
          transfer_group: transfer_group,
          metadata: {
            payment_type: Payment.payment_types[:pay_view_stream],
            amount: sent_amount,
            viewer: sender.username,
          },
        })
        return 'Stripe operation failed' if stripe_transfer['id'].blank?

        Payment.create(
          sender_id: sender.id,
          receiver_id: receiver.id,
          payment_type: Payment.payment_types[:pay_view_stream],
          payment_token: stripe_charge_id,
          sent_amount: received_amount - shared_amount,
          received_amount: received_amount - shared_amount,
          payment_fee: 0,
          fee: 0,
          tax: 0,
          assoc_type: stream.class.name,
          assoc_id: stream.id,
          status: Payment.statuses[:done]
        )
      end

      Payment.create(
        sender_id: sender.id,
        receiver_id: User.public_relations_user.id,
        payment_type: Payment.payment_types[:pay_view_stream],
        payment_token: stripe_charge_id,
        sent_amount: sent_amount,
        received_amount: app_fee,
        payment_fee: stripe_fee,
        fee: 0,
        tax: 0,
        assoc_type: stream.class.name,
        assoc_id: stream.id,
        status: Payment.statuses[:done]
      )
    end

    def view_stream_collaborate(
      sender: nil,
      stream: nil,
      paid_amount: 0,
      transfer_group: nil,
      payment_token: nil
    )
      shared_amount = 0

      if stream.collaborators_count > 0
        user_stream = UserStream.where(
          stream_id: stream.id,
          user_type: UserStream.user_types[:creator],
          status: UserStream.statuses[:accepted]
        ).first
        creator_share = user_stream.user_share
        creator_recoup_cost = user_stream.recoup_cost
        recoup_paid_amount = user_stream.recoup_paid
        recoup_paid = true
        recoup_remain_amount = 0
        recoup_current_amount = 0

        if recoup_paid_amount < creator_recoup_cost
          recoup_paid = false
          recoup_remain_amount = creator_recoup_cost - recoup_paid_amount
        end

        ### user_stream.user is receiver, stream creator, but make sure he connected to stripe
        if user_stream.user.stripe_connected && creator_recoup_cost > 0
          ### item_total_cost diminished
          if !recoup_paid
            recoup_current_amount = paid_amount > recoup_remain_amount ? recoup_remain_amount : paid_amount
            recoup_remain_amount -= recoup_current_amount
            paid_amount -= recoup_current_amount
            shared_amount += recoup_current_amount

            if recoup_current_amount > 0
              stripe_transfer = Stripe::Transfer.create({
                amount: recoup_current_amount,
                currency: 'usd',
                source_transaction: payment_token,
                destination: user_stream.user.payment_account_id,
                description: Payment.payment_types[:recoup],
                transfer_group: transfer_group,
                metadata: {
                  payment_type: Payment.payment_types[:recoup],
                  stream: stream.name,
                  recoup_remain_amount: recoup_remain_amount,
                  viewer: sender.username,
                }
              })
              return 'Stripe operation failed' if stripe_transfer['id'].blank?

              Payment.create(
                sender_id: sender.id,
                receiver_id: user_stream.user.id,
                payment_type: Payment.payment_types[:recoup],
                payment_token: stripe_transfer['id'],
                sent_amount: recoup_current_amount,
                received_amount: recoup_current_amount,
                payment_fee: 0,
                fee: 0,
                tax: 0,
                assoc_type: stream.class.name,
                assoc_id: stream.id,
                status: Payment.statuses[:done]
              )
            end

            user_stream.update_attributes(recoup_paid: user_stream.recoup_paid + recoup_current_amount)
          end
        end

        if paid_amount > 0
          user_streams = UserStream.where(
            stream_id: stream.id,
            user_type: UserStream.user_types[:collaborator],
            status: UserStream.statuses[:accepted]
          )
          user_streams.each do |user_stream|
            ### cannot share the amount because collaborate did not connect to stripe
            next unless user_stream.user.stripe_connected

            collaborator_amount = (paid_amount * user_stream.user_share / 100).floor

            if collaborator_amount > 0
              stripe_transfer = Stripe::Transfer.create({
                amount: collaborator_amount,
                currency: 'usd',
                source_transaction: payment_token,
                destination: user_stream.user.payment_account_id,
                description: Payment.payment_types[:stream_collaborate],
                transfer_group: transfer_group,
                metadata: {
                  payment_type: Payment.payment_types[:stream_collaborate],
                  stream: stream.name,
                  viewer: sender.username,
                }
              })
              next if stripe_transfer['id'].blank?

              Payment.create(
                sender_id: sender.id,
                receiver_id: user_stream.user_id,
                payment_type: Payment.payment_types[:stream_collaborate],
                payment_token: stripe_transfer['id'],
                sent_amount: collaborator_amount,
                received_amount: collaborator_amount,
                payment_fee: 0,
                fee: 0,
                tax: 0,
                user_share: user_stream.user_share,
                assoc_type: stream.class.name,
                assoc_id: stream.id,
                status: Payment.statuses[:done]
              )

              shared_amount += collaborator_amount
            end
          end
        end
      end

      shared_amount
    end

    def refund_without_fee(payment: nil, amount: 0, description: '')
      return false
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
        payment.update_columns!(refund_amount: payment.refund_amount + amount)
        receiver.update_columns!(balance_amount: receiver.balance_amount - amount)
        sender.update_columns!(balance_amount: sender.balance_amount + amount)
      end
      _payment
    end

    def refund_order(payment: nil, amount: 0, description: '', items: nil)
      return false
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
          item.mark_as_refunded(refund_amount: it['refund_amount'])
        end
        payment.update_columns!(refund_amount: payment.refund_amount + amount, description: description)
        receiver.update_columns!(balance_amount: receiver.balance_amount - amount)
        sender.update_columns!(balance_amount: sender.balance_amount + amount)
      end

      _payment
    end

    def withdraw(user_id: nil, amount: 0)
      return false
      user = User.find_by(id: user_id)
      return 'Not found a user' unless user.present?
      return 'Not connect to stripe yet' unless user.stripe_connected
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

      user.update_columns(balance_amount: user.balance_amount - amount)

      payment = Payment.create(
        sender_id: user.id,
        receiver_id: user.id,
        payment_type: Payment.payment_types[:withdraw],
        payment_token: stripe_transfer['id'],
        sent_amount: amount,
        received_amount: 0,
        payment_fee: 0,
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
          stripe_account: user.payment_account_id
        })
      rescue => ex
      end

      # return "Success in Payout: #{stripe_payout['id']}"
      payment
    end

    def calculate_fee(amount, fee_type, fee_description = '')
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

    # def stripe_fee(amount)
    #   (amount * 0.029 + 30).round
    # end

    def stripe_fee(amount)
      total = ((amount + 30) / 0.971).round
      fee1 = (total * 0.029 + 30).round
      fee = total - amount

      puts "\n\n +++++ stripe_fee +++++"
      puts "#{fee} : #{fee1}"
      puts "\n\n\n"

      fee
    end

    def precheck(entities, stripe_connected_users, payment_token)
      return 'Payment token not specified' if payment_token.blank?

      entities.each do |entity|
        return 'Entity not found' if entity.blank?
      end

      stripe_connected_users.each do |user|
        return "Receiver not found" if user.blank?
        return "Receiver not connected to stripe" unless user.stripe_connected
      end

      return true
    end
  end
end
