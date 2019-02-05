module Api::V1::Shopping
  class ItemsController < ApiController
    before_action :set_item, only: [:mark_as_shipped, :mark_as_unshipped]
    skip_after_action :verify_policy_scoped
    skip_after_action :verify_authorized, except: [:mark_as_shipped, :mark_as_unshipped]

    swagger_controller :items, 'Item'

    swagger_api :index do |api|
      summary 'get items in the cart'
    end
    def index
      items = current_cart.items
      render json: ActiveModel::Serializer::CollectionSerializer.new(
        items,
        serializer: ShopItemSerializer,
        scope: OpenStruct.new(current_user: current_user)
      )
    end


    swagger_api :create do |api|
      summary 'add an item to the cart'
      param :form, :product_variant_id, :string, :required
      param :form, :quantity, :integer, :required
      param :form, :page_track, :string, :optional
    end
    def create
      quantity = params[:quantity].present? ? params[:quantity].to_i : 1
      quantity = 1 if quantity < 1

      result = current_cart.add(params[:product_variant_id], quantity, params[:page_track], current_user)
      if result === true
        # render_success(true)
        render json: current_cart.calculate_cost(current_user.default_address.try(:country), current_user.default_address.try(:state))
      else
        render_error result, :unprocessable_entity
      end
    end


    swagger_api :update do |api|
      summary 'update an item'
      param :path, :id, :string, :required
      param :form, :quantity, :integer, :required
    end
    def update
      quantity = params[:quantity].present? ? params[:quantity].to_i : 1
      quantity = 1 if quantity < 1
      current_cart.modify(params[:id], quantity)

      # render_success(true)
      render json: current_cart.calculate_cost(current_user.default_address.try(:country), current_user.default_address.try(:state))
    end


    swagger_api :destroy do |api|
      summary 'delete an item'
      param :path, :id, :string, :required
    end
    def destroy
      current_cart.remove(params[:id])
      # render_success(true)
      render json: current_cart.calculate_cost(current_user.default_address.try(:country), current_user.default_address.try(:state))
    end


    setup_authorization_header(:calculate_cost)
    swagger_api :calculate_cost do |api|
      summary 'calculate shipping cost on the items in a cart'
      param :query, :country, :string, :optional
      param :query, :state, :string, :optional
    end
    def calculate_cost
      country = params[:country].present? ? params[:country] : ShopAddress::COUNTRY_EVERYWHERE_ELSE
      state = params[:state].present? ? params[:state] : ''
      render json: current_cart.calculate_cost(country, state)
    end


    setup_authorization_header(:buy)
    swagger_api :buy do |api|
      summary 'buy items'
      param :form, :shipping_address_id, :string, :required
      param :form, :payment_token, :string, :optional
    end
    def buy
      orders = current_cart.buy(params[:shipping_address_id], params[:payment_token])
      if orders.kind_of?(Array)
        render json: ActiveModel::Serializer::CollectionSerializer.new(
          orders,
          serializer: ShopOrderSerializer,
          scope: OpenStruct.new(current_user: current_user),
        )
      else
        render_error orders, :unprocessable_entity
      end
    end


    setup_authorization_header(:mark_as_shipped)
    swagger_api :mark_as_shipped do |api|
      summary 'mark an item as shipped'
      param :path, :id, :string, :required
    end
    def mark_as_shipped
      authorize @item
      @item.mark_as_shipped
      render_success true
    end


    setup_authorization_header(:mark_as_unshipped)
    swagger_api :mark_as_unshipped do |api|
      summary 'mark an item as unshipped'
      param :path, :id, :string, :required
    end
    def mark_as_unshipped
      authorize @item
      @item.update_attributes(status: ShopItem.statuses[:item_ordered])
      if @item.order.order_shipped?
        @item.order.update_attributes(status: ShopOrder.statuses[:order_pending])
      end
      ActionCable.server.broadcast("notification_#{current_user.id}", {sell: 1})
      render_success true
    end


    setup_authorization_header(:mark_all_as_shipped)
    swagger_api :mark_all_as_shipped do |api|
      summary 'mark all items as shipped'
    end
    def mark_all_as_shipped
      unshipped_items_size = ShopItem.where(
        merchant_id: current_user.id,
        status: ShopItem.statuses[:item_ordered]
      ).size

      ShopItem.where(
        merchant_id: current_user.id,
        status: ShopItem.statuses[:item_ordered]
      ).update_all(status: ShopItem.statuses[:item_shipped])

      ShopOrder.where(
        merchant_id: current_user.id,
        status: ShopOrder.statuses[:order_pending]
      ).update_all(status: ShopOrder.statuses[:order_shipped])

      ActionCable.server.broadcast("notification_#{current_user.id}", {sell: -unshipped_items_size})

      render_success true
    end

    private
    def set_item
      @item = ShopItem.includes(:order).find(params[:id])
    end
  end
end