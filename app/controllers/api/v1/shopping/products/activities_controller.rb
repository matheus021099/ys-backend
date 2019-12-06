module Api::V1::Shopping
  class Products::ActivitiesController < ApiController
    # skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    before_action :set_product

    swagger_controller :activities, 'products/{id}/activities'

    swagger_api :index do |api|
      summary 'list activities'
      param :path, :product_id, :string, :required
      param :query, :action_type, :string, :required, 'repost, order_product'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      action_type = params[:action_type] || 'repost'
      join_query = nil

      case action_type
        when 'order_product'
          join_query = Activity.joins(
            "INNER JOIN shop_orders o ON activities.assoc_id = o.id AND activities.assoc_type = 'ShopOrder' "\
            "JOIN shop_items i ON o.id = i.order_id"
          ).where("i.product_id = ?", @product.id)
        else
          join_query = Activity.for_product(@product.id)
      end

      join_query = join_query.where.not(sender_id: @product.merchant_id)
            .where(action_type: action_type)
            .select('DISTINCT ON (activities.sender_id) activities.id, activities.sender_id, activities.created_at')
            .order(sender_id: :asc, created_at: :desc).to_sql

      activities = Activity.select('t1.*').from('activities t1').order('t1.created_at DESC')
        .joins("INNER JOIN (#{join_query}) t2 ON t1.id = t2.id")
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end

    swagger_api :stats do |api|
      summary 'product stats'
      param :path, :product_id, :string, :required
    end
    def stats
      reposts_size = Activity.for_product(@product.id)
        .where.not(sender_id: @product.merchant_id)
        .where(action_type: Activity.action_types[:repost])
        .group(:sender_id).count.size

      orders_size = ShopOrder.for_product(@product.id).size

      result = {
        reposts_size: reposts_size,
        orders_size: orders_size
      }

      render json: result
    end

    private
    def set_product
      @product = ShopProduct.find(params[:product_id])
    end
  end
end
