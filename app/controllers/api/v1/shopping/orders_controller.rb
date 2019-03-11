require 'csv'

module Api::V1::Shopping
  class OrdersController < ApiController
    include ActionView::Helpers::NumberHelper

    before_action :set_order, only: [:show, :hide_customer_address]

    swagger_controller :orders, 'Order'

    swagger_api :index do |api|
      summary 'admin - all orders'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      skip_policy_scope
      orders = ShopOrder.all
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)
      render_success(
        orders: ActiveModel::Serializer::CollectionSerializer.new(
          orders,
          serializer: ShopOrderSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(orders)
      )
    end


    setup_authorization_header(:sent)
    swagger_api :sent do |api|
      summary 'orders a user made'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def sent
      skip_policy_scope
      skip_authorization
      orders = ShopOrder.where(customer: current_user)
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)
      render_success(
        orders: ActiveModel::Serializer::CollectionSerializer.new(
          orders,
          serializer: ShopOrderSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(orders)
      )
    end


    setup_authorization_header(:received)
    swagger_api :received do |api|
      summary 'orders a user received'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
      param :query, :status, :string, :optional, 'creator_unshipped, creator_shipped, collaborator_unshipped, collaborator_shipped'
    end
    def received
      skip_policy_scope
      skip_authorization

      status = params[:status] || ''
      query = ShopItem
        .joins(:product => [:user_products])
        .where.not(order_id: nil)
        .where(users_products: {
          status: UserProduct.statuses[:accepted],
          user_id: current_user.id
        })
      case status
        when 'creator_unshipped'
          query = query.where(
            users_products: {
              user_type: UserProduct.user_types[:creator]
            },
            status: ShopItem.statuses[:item_ordered]
          )
        when 'creator_shipped'
          query = query.where(
            users_products: {
              user_type: UserProduct.user_types[:creator]
            },
            status: ShopItem.statuses[:item_shipped]
          )
        when 'collaborator_unshipped'
          query = query.where(
            users_products: {
              user_type: UserProduct.user_types[:collaborator]
            },
            status: ShopItem.statuses[:item_ordered]
          )
        when 'collaborator_shipped'
          query = query.where(
            users_products: {
              user_type: UserProduct.user_types[:collaborator]
            },
            status: ShopItem.statuses[:item_shipped]
          )
        else
          query = query.where(
            users_products: {
              user_type: [
                UserProduct.user_types[:creator],
                UserProduct.user_types[:collaborator]
              ]
            }
          )
      end
      order_ids = query.group(:order_id).pluck(:order_id)

      orders = ShopOrder.includes(:customer, :merchant, :items).where(id: order_ids)
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        orders: ActiveModel::Serializer::CollectionSerializer.new(
          orders,
          serializer: ShopOrderSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(orders)
      )
    end


    setup_authorization_header(:received_export)
    swagger_api :received_export do |api|
      summary 'export orders a user received in csv format '
    end
    def received_export
      skip_policy_scope
      skip_authorization

      order_ids = ShopItem
        .where.not(order_id: nil)
        .where(merchant_id: current_user.id)
        .group(:order_id)
        .pluck(:order_id)

      orders = ShopOrder.includes(:customer, :shipping_address, items: [:product, :product_variant])
        .where(id: order_ids)
        .order(created_at: :desc)

      csv_string = CSV.generate do |csv|
        csv << [
          'order_created', 'order_id', 'user_type',
          'customer_name', 'shipping_email', 'shipping_address',
          'item_id', 'product_name', 'product_variant_name',
          'price', 'quantity', 'shipping_cost', 'total_cost', 'status'
        ]
        orders.each do |order|
          user_type = 'creator'
          order.items.each do |item|
            csv << [
              order.created_at.strftime('%Y-%m-%d'), Util::Number.encode(order.id), user_type,
              order.customer.display_name, order.shipping_address.email, order.shipping_address.to_full_address,
              item.id, item.product.name, item.product_variant.name,
              number_to_currency(item.price / 100.0, unit: ''), number_to_currency(item.shipping_cost / 100.0, unit: ''),
              item.quantity, number_to_currency(item.total_cost / 100.0, unit: ''), item.status
            ]
          end
        end
      end

      filename = "order-items-#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
      send_data csv_string, :type => 'text/csv; charset=utf-8; header=present', disposition: :attachment, filename: filename
    end


    swagger_api :show do |api|
      summary 'show an order'
      param :path, :id, :string, :required
    end
    def show
      authorize @order
      render json: @order,
        serializer: ShopOrderSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_payments: true
    end


    swagger_api :hide_customer_address do |api|
      summary 'hide customer address from seller'
      param :path, :id, :string, :required
    end
    def hide_customer_address
      authorize @order
      ShopOrder.where(
        customer_id: @order.customer_id,
        merchant_id: @order.merchant_id,
        status: ShopOrder.statuses[:order_shipped]
      ).update_all(
        enabled_address: false
      )
      render_success true
    end


    private
    def set_order
      order_id = Util::Number.decode(params[:id])
      @order = ShopOrder.find(order_id)
      # @order = ShopOrder.find(params[:id])
    end
  end
end