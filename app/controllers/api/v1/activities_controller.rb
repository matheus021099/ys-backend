module Api::V1
  class ActivitiesController < ApiController
    swagger_controller :activities, 'Activities'

    swagger_api :index do |api|
      summary 'list all activities'
      param :query, :action_types, :string, :optional, 'any, repost, download, play, signin, etc'
      param :query, :include_own, :boolean, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
      # param :query, :device_platform, :string, :optional, 'ios, android, web. default is ios'
    end
    def index
      action_types = params[:action_types].present? ? params[:action_types].split(',').map(&:strip) : ['any']
      include_own = params[:include_own].present? ? ActiveModel::Type::Boolean.new.cast(params[:include_own]) : false
      # device_platform = params[:device_platform] || 'ios'
      exclude_user_ids = current_user.block_list

      activities = policy_scope(Activity).order('updated_at desc')
      activities = activities.where.not(sender_id: exclude_user_ids)
      activities = activities.where.not(sender_id: current_user.id) unless include_own
      # if device_platform.blank?
      #   activities = activities.where.not(action_type: [
      #     Activity.action_types[:play],
      #     Activity.action_types[:unfollow]
      #   ])
      # else
      #   activities = activities.where.not(action_type: [
      #     Activity.action_types[:play],
      #     Activity.action_types[:unfollow],
      #     Activity.action_types[:repost_by_following]
      #   ])
      # end
      activities = activities.where.not(action_type: [
        Activity.action_types[:play],
        Activity.action_types[:unfollow],
        Activity.action_types[:repost_by_following]
      ])
      activities = activities.where(action_type: action_types) unless action_types.include?('any')
      activities = activities.where.not(module_type: Activity.module_types[:log])
      activities = activities.page(params[:page] || 1).per(params[:per_page] || 10)
      # render_success(activities)
      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end


    swagger_api :metrics do |api|
      summary 'activities count from specific page'
      param :query, 'page_track', :string, :required
      # param :form, 'page_type', :string, :required
      # param :form, 'page_id', :string, :optional
    end
    def metrics
      skip_authorization

      # page_type = params[:page_type] || ''
      # page_id = params[:page_id] || ''
      page_track = params[:page_track] || ''

      # sz = Activity.where(page_track: page_track).group(:assoc_type).count
      views_size = Activity.where('sender_id = receiver_id').where(
        page_track: page_track,
        action_type: Activity.action_types[:view_stream]
      ).size
      downloads_size = Activity.where('sender_id = receiver_id').where(
        page_track: page_track,
        assoc_type: 'Album',
        action_type: Activity.action_types[:download]
      ).size
      carts_size = Activity.where('sender_id = receiver_id').where(
        page_track: page_track,
        assoc_type: 'ShopProduct',
        action_type: Activity.action_types[:add_to_cart]
      ).size
      followed_size = Activity.where('sender_id = receiver_id').where(
        page_track: page_track,
        action_type: Activity.action_types[:follow]
      ).size

      result = {
        views_size: views_size,
        downloads_size: downloads_size,
        carts_size: carts_size,
        followed_size: followed_size
      }
      render json: result
    end


    setup_authorization_header(:unread)
    swagger_api :unread do |api|
      summary 'get new notifications'
    end
    def unread
      skip_authorization

      # skip_policy_scope
      # activity_notes = Activity.received_by(current_user.id).activity.unread
      # stream_notes = Activity.received_by(current_user.id).stream.unread

      exclude_user_ids = current_user.block_list

      activity_new_count = policy_scope(Activity).activity.unread.where.not(sender_id: exclude_user_ids).count
      stream_new_count = policy_scope(Activity).stream.unread.where.not(sender_id: exclude_user_ids).count
      items_count = current_cart.items.size
      ### actually received order items count
      received_order_count = ShopOrder.joins(:items).where(
        merchant_id: current_user.id,
        shop_items: {
          status: ShopItem.statuses[:item_ordered]
        }
      ).size

      blocked_users = current_user.blocked_user_objects
      blocked_conversation_ids = []
      blocked_users.each do |blocked_user|
        blocked_conversation_ids.concat current_user.mailbox.conversations_with(blocked_user).collect(&:id)
      end
      # message_new_count = current_user.mailbox.inbox({read: false}).where.not(id: blocked_conversation_ids).distinct.count(:id)
      message_new_count = current_user.mailbox.conversations({read: false}).where.not(id: blocked_conversation_ids).distinct.count(:id)

      result = {
        activity: activity_new_count,
        stream: stream_new_count,
        message: message_new_count,
        cart: items_count,
        sell: received_order_count
      }
      render json: result
    end


    setup_authorization_header(:read)
    swagger_api :read do |api|
      summary 'set status to read on module'
      param :query, :module_type, :string, :required, 'activity, stream, etc.'
    end
    def read
      skip_authorization
      # puts "\n\n #{params[:module_type]}, #{Activity.module_types[params[:module_type]]} \n\n\n"
      policy_scope(Activity).where(module_type: Activity.module_types[params[:module_type]], status: 'unread').update_all(status: 'read')
      render_success true
    end

  end
end
