require 'net/http'

module Api::V1
  class UsersController < ApiController
    include ActionView::Helpers::NumberHelper

    skip_before_action :authenticate_token!, only: [:info]
    before_action :authenticate_token, only: [:info]
    # skip_after_action :verify_authorized, only: [:hidden_genres]
    before_action :set_user, only: [
      :update, :destroy, :repost_price_proration, :set_repost_price, :change_password,
      :connect_stripe, :disconnect_stripe, :instant_payouts, :donate,
      :info, :invite, :reposted_feeds, :cart_items,
      :has_followed, :follow, :unfollow, :block, :unblock, :favorite, :unfavorite,
      :hidden_genres, :available_stream_period,
      :send_label_request, :remove_label, :accept_label_request, :deny_label_request,
      :share,
      :update_status, :update_role
    ]

    swagger_controller :users, 'user'

    swagger_api :index do |api|
      summary 'get users'
      param :query, :filter, :string, :optional, 'any, co-sign'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      skip_policy_scope
      render_error('You are not authorized', :unprocessable_entity) and return unless current_user.admin? || current_user.moderator?

      filter = params[:filter] || 'any'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 25).to_i

      #TODO - set roles according to current_user's role
      # roles = [:superadmin] if current_user.superadmin?
      # roles = [:superadmin, :admin] if current_user.admin?

      users = User.where.not(
        id: current_user.id,
        user_type: [ User.user_types[:superadmin], User.user_types[:admin] ],
        status: User.statuses[:deleted]
      )
      case filter
        when 'co-sign'
          users = users.with_role(:listener).where(
            status: User.statuses[:active],
            request_role: ['artist', 'brand', 'label']
          )
      end
      # users = users.page(page).per(per_page)

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_social_info: true,
          include_all: true,
        ),
        # pagination: pagination(users)
      )
    end


    swagger_api :search do |api|
      summary 'search users'
      param :query, :q, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def search
      skip_policy_scope
      # render_error('requires admin role', :unprocessable_entity) and return unless current_user.admin?

      q = params[:q] || '*'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i
      orders = {username: :asc}

      #TODO - set roles according to current_user's role
      # roles = [:superadmin] if current_user.superadmin?
      # roles = [:superadmin, :admin] if current_user.admin?
      exclude_ids = User.where(user_type: [ User.user_types[:superadmin], User.user_types[:admin] ]).pluck(:id)
      exclude_ids << current_user.id
      exclude_ids += User.tagged_with(current_user.id, :on => :blocks).pluck(:id)

      users = User.search(
        q,
        fields: [:username, :email],
        where: {id: {not: exclude_ids}, status: {not: User.statuses[:deleted]}},
        order: orders,
        limit: per_page,
        offset: (page - 1) * per_page
      )

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_social_info: false,
        ),
        pagination: pagination(users)
      )
    end


    swagger_api :update do |api|
      summary 'update user profile'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, 'user[display_name]', :string, :optional
      param :form, 'user[first_name]', :string, :optional
      param :form, 'user[last_name]', :string, :optional
      param :form, 'user[contact_url]', :string, :optional
      param :form, 'user[email]', :string, :optional
      param :form, 'user[avatar]', :File, :optional
      # param :form, 'user[password]', :string, :optional
      # param :form, 'user[repost_price]', :integer, :optional
      param :form, 'user[enable_alert]', :integer, :optional
      param :form, 'user[message_visited]', :integer, :optional, '1 - visited'

      param :form, 'user[return_policy]', :string, :optional
      param :form, 'user[shipping_policy]', :string, :optional
      param :form, 'user[size_chart]', :string, :optional
      param :form, 'user[privacy_policy]', :string, :optional

      # param :form, "user[request_role]", :string, :optional, 'artist, brand, label'
      # param :form, "user[social_user_id]", :string, :optional
      param :form, "user[genre_id]", :string, :optional
      param :form, "user[release_count]", :string, :optional
      param :form, "user[soundcloud_url]", :string, :optional
      param :form, "user[basecamp_url]", :string, :optional
      param :form, "user[website_url]", :string, :optional
      param :form, "user[history]", :string, :optional
      param :form, "user[request_resend]", :string, :optional
    end
    def update
      authorize @user
      render_error 'No params', :unprocessable_entity and return if params[:user].blank?

      attributes = permitted_attributes(@user)

      # @user.message_first_visited_time = Time.now if params[:user][:message_visited].to_i == 1
      @user.data['message_page_visited'] = 1 if params[:user][:message_page_visited].to_i == 1
      @user.data['video_page_visited'] = 1 if params[:user][:video_page_visited].to_i == 1
      @user.data['sell_page_visited'] = 1 if params[:user][:sell_page_visited].to_i == 1
      @user.data['discover_page_visited'] = 1 if params[:user][:discover_page_visited].to_i == 1
      @user.data['stream_page_visited'] = 1 if params[:user][:stream_page_visited].to_i == 1
      @user.data['label_page_visited'] = 1 if params[:user][:label_page_visited].to_i == 1

      unless params[:user][:avatar].instance_of? ActionDispatch::Http::UploadedFile
        attributes.delete('avatar')
      end

      @user.request_status = User.request_statuses[:pending] if params[:user][:request_resend].present?

      if @user.update(attributes)
        render json: @user,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_all: true,
          include_social_info: @user.id == current_user.id
      else
        render_errors(@user, :unprocessable_entity)
      end
    end


    swagger_api :destroy do |api|
      summary 'delete a user'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def destroy
      authorize @user
      @user.remove
      render_success true
    end

=begin
    setup_authorization_header(:repost_price_proration)
    swagger_api :repost_price_proration do |api|
      summary 'calculate repost price proration'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def repost_price_proration
      authorize @user

      now = Time.zone.now
      if @user.repost_price == 100 || @user.repost_price_end_at.nil? || @user.repost_price_end_at <= now
        result = {
          spent_amount: @user.repost_price,
          remaining_amount: 0
        }
        render_success result
        return
      end

      started_at = @user.repost_price_end_at.ago(1.year)
      spent_amount = (@user.repost_price * (now - started_at) / (@user.repost_price_end_at - started_at)).to_i
      result = {
        spent_amount: spent_amount,
        remaining_amount: @user.repost_price - spent_amount
      }
      render_success result
    end


    setup_authorization_header(:set_repost_price)
    swagger_api :set_repost_price do |api|
      summary 'set repost price'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :repost_price, :integer, :required
      param :form, :payment_amount, :integer, :required
      param :form, :payment_token, :string, :optional
    end
    def set_repost_price
      authorize @user
      render_error 'Not passed repost price', :unprocessable_entity and return unless params[:repost_price].present?
      payment_token = params[:payment_token] || nil
      payment_amount = params[:payment_amount].to_i rescue 0
      repost_price = params[:repost_price].to_i

      unless @user.repost_price == repost_price
        if repost_price == 100
          @user.repost_price = repost_price
          @user.repost_price_end_at = nil
        else
          if payment_amount > 0
            unless payment_token.blank?
              stripe_charge_id = Payment.deposit(user: @user, payment_token: payment_token, amount: payment_amount)
              render_error 'Failed in stripe charge', :unprocessable_entity and return if stripe_charge_id === false
            else
              stripe_charge_id = nil
              render_error 'Not enough balance', :unprocessable_entity and return if @user.balance_amount < payment_amount
            end
            Payment.set_repost_price(sender: @user, sent_amount: payment_amount, payment_token: stripe_charge_id)
          end

          @user.repost_price = repost_price
          @user.repost_price_end_at = DateTime.now.beginning_of_day.in(1.year)
        end

        @user.save
      end

      render json: @user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: @user.id == current_user.id
    end
=end

    setup_authorization_header(:repost_price_proration)
    swagger_api :repost_price_proration do |api|
      summary 'calculate repost price proration'
      param :path, :id, :string, :required, 'user id or slug'
      param :query, :new_repost_price, :integer, :required, 'new repost price'
    end
    def repost_price_proration
      authorize @user
      new_repost_price = params[:new_repost_price].to_i rescue 100
      proration = @user.repost_price_proration(new_repost_price)
      render_success proration
    end


    setup_authorization_header(:set_repost_price)
    swagger_api :set_repost_price do |api|
      summary 'set repost price'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :repost_price, :integer, :required
      param :form, :payment_amount, :integer, :required
      param :form, :payment_token, :string, :optional
    end
    def set_repost_price
      authorize @user
      render_error 'Not passed repost price', :unprocessable_entity and return unless params[:repost_price].present?
      payment_token = params[:payment_token] || nil
      payment_amount = params[:payment_amount].to_i rescue 0
      repost_price = params[:repost_price].to_i rescue 100
      proration = @user.repost_price_proration(repost_price)
      render_error 'Not enough payment amount', :unprocessable_entity and return if payment_amount < proration[:add_amount]

      if payment_amount == 0
        @user.repost_price = repost_price
      else
        unless payment_token.blank?
          stripe_charge_id = Payment.deposit(user: @user, payment_token: payment_token, amount: payment_amount)
          render_error 'Failed in stripe charge', :unprocessable_entity and return if stripe_charge_id === false
        else
          stripe_charge_id = nil
          render_error 'Not enough balance', :unprocessable_entity and return if @user.balance_amount < payment_amount
        end
        Payment.set_repost_price(sender: @user, sent_amount: payment_amount, payment_token: stripe_charge_id)

        @user.max_repost_price = repost_price
        @user.repost_price = repost_price
        @user.repost_price_end_at = proration[:expire_at]
      end

      @user.save

      render json: @user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: @user.id == current_user.id
    end


    setup_authorization_header(:change_password)
    swagger_api :change_password do |api|
      summary 'change password'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :old_password, :string, :required
      param :form, :new_password, :string, :required
      param :form, :confirmed_password, :string, :required
    end
    def change_password
      authorize @user
      render_error('Invalid old password', :unprocessable_entity) and return unless @user.valid_password?(params[:old_password])
      render_error('Not matched password', :unprocessable_entity) and return unless params[:new_password] === params[:confirmed_password]

      @user.update_attributes(password: params[:new_password])
      render_success(true)
    end


    setup_authorization_header(:connect_stripe)
    swagger_api :connect_stripe do |api|
      summary 'connect stripe'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :code, :string, :required, 'code'
      # param :form, 'user[payment_provider]', :string, :required
      # param :form, 'user[payment_account_id]', :string, :required
      # param :form, 'user[payment_account_type]', :string, :required, 'standalone, etc'
      # param :form, 'user[payment_publishable_key]', :string, :required
      # param :form, 'user[payment_access_code]', :string, :required
    end
    def connect_stripe
      authorize @user

      uri = URI.parse("https://connect.stripe.com/oauth/token")
      response = Net::HTTP.post_form(uri, {
        "client_secret": ENV['STRIPE_SECRET_KEY'],
        "code": params[:code],
        "grant_type": "authorization_code"
      })
      result = JSON.parse(response.body)

      render_error result['error_description'], :unprocessable_entity and return if result['error'].present?

      @user.update_attributes(
        payment_provider: 'stripe',
        payment_account_id: result['stripe_user_id'],
        payment_account_type: 'standalone',
        payment_publishable_key: result['stripe_publishable_key'],
        payment_access_code: result['access_token']
      )

      # render json: response.body
      render json: @user, serializer: UserSerializer, scope: OpenStruct.new(current_user: current_user), include_all: true, include_social_info: false
    end


    setup_authorization_header(:disconnect_stripe)
    swagger_api :disconnect_stripe do |api|
      summary 'disconnect stripe'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def disconnect_stripe
      authorize @user
      @user.update_attributes(
        payment_provider: nil,
        payment_account_id: nil,
        payment_account_type: nil,
        payment_publishable_key: nil,
        payment_access_code: nil
      )
      render json: @user, serializer: UserSerializer, scope: OpenStruct.new(current_user: current_user), include_all: true, include_social_info: false
    end


    setup_authorization_header(:instant_payouts)
    swagger_api :instant_payouts do |api|
      summary 'payouts instantly using stripe'
    end
    def instant_payouts
      authorize @user
      # Stripe::Payout.create(
      #   {
      #     :amount => 1000,
      #     :currency => "usd",
      #     :method => "instant"
      #   },
      #   {:stripe_account => CONNECTED_STRIPE_ACCOUNT_ID}
      # )
      render_success true
    end


    setup_authorization_header(:donate)
    swagger_api :donate do |api|
      summary 'send love donation'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :amount, :integer, :required, 'amount in cent'
      param :form, :payment_token, :string, :optional
      param :form, :description, :string, :optional
    end
    def donate
      authorize @user rescue render_error "You can't donate to yourself", :unprocessable_entity and return
      # amount = params[:amount] ? params[:amount].to_i : 0
      amount = params[:amount].to_i || 0
      description = params[:description] || 'Donation'
      render_error 'Please enter the amount', :unprocessable_entity and return if amount < 100
      payment = current_user.donate(
        receiver: @user,
        amount: amount,
        payment_token: params[:payment_token],
        description: description
      )
      render_error payment, :unprocessable_entity and return unless payment.kind_of? Payment
      # render json: payment, serializer: PaymentSerializer, scope: OpenStruct.new(current_user: current_user)

      sender = current_user
      receiver = @user
      message_body = "I just sent you #{number_to_currency(amount / 100.0)} for #{description}"
      Util::Message.send(sender, receiver, message_body)

      Activity.create(
        sender_id: current_user.id,
        receiver_id: @user.id,
        message: "#{current_user.display_name} sent you #{number_to_currency(amount / 100.0)} for #{description}",
        assoc_type: payment.class.name,
        assoc_id: payment.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:donation],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread]
      )
      Activity.create(
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: "sent #{@user.display_name} #{number_to_currency(amount / 100.0)} for #{description}",
        assoc_type: payment.class.name,
        assoc_id: payment.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:donation],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:read]
      )

      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: false
    end


    swagger_api :info do |api|
      summary 'get user info'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def info
      authorize @user
      render json: @user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: current_user && (@user.id == current_user.id)
    end


    swagger_api :invite do |api|
      summary 'invite a user'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def invite
      authorize @user
      # #TODO rename -> cosign or remove it
      @user.update_attributes(
        consigned: true,
        inviter_id: current_user.id,
        invited_at: Time.now
      )
      render json: @user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: current_user && (@user.id == current_user.id)
    end


    setup_authorization_header(:reposted_feeds)
    swagger_api :reposted_feeds do |api|
      summary 'return current user items(feeds) which a user has reposted'
      param :path, :id, :string, :required, 'user id'
    end
    def reposted_feeds
      skip_authorization

      # table_sql = <<-SQL
      #   SELECT MAX(id) AS id, assoc_id, assoc_type
      #   FROM feeds
      #   WHERE publisher_id='#{@user_id}'
      #     AND feed_type = #{Feed.feed_types[:repost].to_s}
      #   GROUP BY assoc_id, assoc_type
      # SQL
      # album_feeds = Feed
      #   .select('t1.*')
      #   .from('feeds t1')
      #   .joins("RIGHT JOIN (#{table_sql}) t2 ON t1.id = t2.id")
      #   .order('updated_at desc')
      #   .where(
      #     users_albums: {
      #       user_id: self.id,
      #       user_type: [
      #         UserAlbum.user_types[:creator],
      #         UserAlbum.user_types[:collaborator],
      #         UserAlbum.user_types[:label]
      #       ]
      #     }
      #   )

      feeds = @user.repost_query(nil, nil)
      render json: feeds.as_json(only: [:id, :assoc_id, :assoc_type])
      # render json: ActiveModel::Serializer::CollectionSerializer.new(
      #   feeds,
      #   serializer: FeedSerializer,
      #   scope: OpenStruct.new(current_user: current_user),
      #   exclude_assoc: true
      # )
    end


    setup_authorization_header(:cart_items)
    swagger_api :cart_items do |api|
      summary 'return cart_items'
      param :path, :id, :string, :required, 'user id'
    end
    def cart_items
      skip_authorization

      render json: @user.current_cart.items.as_json(only: [:id, :product_id])
    end


    setup_authorization_header(:has_followed)
    swagger_api :has_followed do |api|
      summary 'check current_user has followed a user'
      param :path, :id, :string, :required, 'following user id'
    end
    def has_followed
      skip_authorization
      render json: { has_followed: current_user.following?(@user) }
    end


    setup_authorization_header(:follow)
    swagger_api :follow do |api|
      summary 'follow a user'
      param :path, :id, :string, :required, 'following user id'
      param :query, :page_track, :string, :optional
    end
    def follow
      authorize @user, :follow?
      current_user.follow(@user)
      page_track = params[:page_track] || ''

      @user.albums.published.each do |album|
        Feed.insert(
          consumer_id: current_user.id,
          publisher_id: @user.id,
          assoc_type: 'Album',
          assoc_id: album.id,
          feed_type: Feed.feed_types[:release]
        )
      end

      @user.products.published.each do |product|
        Feed.insert(
          consumer_id: current_user.id,
          publisher_id: @user.id,
          assoc_type: 'ShopProduct',
          assoc_id: product.id,
          feed_type: Feed.feed_types[:release]
        )
      end

      Activity.create(
        sender_id: current_user.id,
        receiver_id: @user.id,
        message: 'followed you',
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:follow],
        alert_type: Activity.alert_types[:both],
        page_track: page_track,
        status: Activity.statuses[:unread]
      )

      #TODO - alert if following user (@user) has published albums
      Activity.create(
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: 'updated your stream',
        module_type: Activity.module_types[:stream],
        action_type: Activity.action_types[:follow],
        alert_type: Activity.alert_types[:both],
        page_track: page_track,
        status: Activity.statuses[:read],
      )

      ### for now, page_track is available for stream
      if page_track.present?
        class_name, instance_id = page_track.split(':').map(&:strip)
        if class_name.present? && instance_id.present?
          begin
            @stream = class_name.constantize.find(instance_id)
            ActionCable.server.broadcast("stream_#{@stream.id}", {followed_size: 1})
          rescue e
            Rails.logger.info(e.message)
          end
        end
      end

      render_success(true)
    end


    setup_authorization_header(:unfollow)
    swagger_api :unfollow do |api|
      summary 'unfollow a user'
      param :path, :id, :string, :required, 'following user id'
    end
    def unfollow
      authorize @user
      current_user.stop_following(@user)

      Feed.where({
        consumer_id: current_user.id,
        publisher_id: @user.id
      }).destroy_all

      Activity.create(
        sender_id: current_user.id,
        receiver_id: @user.id,
        message: 'unfollowed you',
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:unfollow],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread]
      )

      #TODO - alert if following user (@user) has published albums
      Activity.create(
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: 'updated your stream',
        module_type: Activity.module_types[:stream],
        action_type: Activity.action_types[:unfollow],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread],
      )

      render_success(true)
    end


    setup_authorization_header(:block)
    swagger_api :block do |api|
      summary 'block a user'
      param :path, :id, :string, :required
    end
    def block
      authorize @user
      current_user.stop_following(@user)
      # #TODO - consider in not to remove paid-repost
      Feed.where(
        consumer_id: @user.id,
        publisher_id: current_user.id
      ).destroy_all
      current_user.block_list.add(@user.id)
      current_user.save
      render_success true
    end


    setup_authorization_header(:unblock)
    swagger_api :unblock do |api|
      summary 'unblock a user'
      param :path, :id, :string, :required
    end
    def unblock
      authorize @user
      current_user.block_list.remove(@user.id)
      current_user.save
      render_success true
    end


    setup_authorization_header(:favorite)
    swagger_api :favorite do |api|
      summary 'add a user to favorite list - used in promote modal'
      param :path, :id, :string, :required
    end
    def favorite
      authorize @user
      current_user.favorite_list.add(@user.id)
      current_user.save
      render_success true
    end


    setup_authorization_header(:unfavorite)
    swagger_api :unfavorite do |api|
      summary 'remove a user from favorite list - used in promote modal'
      param :path, :id, :string, :required
    end
    def unfavorite
      authorize @user
      current_user.favorite_list.remove(@user.id)
      current_user.save
      render_success true
    end


    # user - settings
    setup_authorization_header(:hidden_genres)
    swagger_api :hidden_genres do |api|
      summary 'hidden genres'
      param :path, :id, :string, :required
      param :form, :genre_ids, :string, :optional
    end
    def hidden_genres
      authorize @user
      genre_ids = params[:genre_ids].split(',').compact if params[:genre_ids]
      if genre_ids.blank?
        @user.genre_list = []
        @user.save
      else
        # @user.genre_list = Genre.where(id: genre_ids).pluck(:name)
        @user.genre_list = Genre.where(id: genre_ids).pluck(:id)
        @user.save
      end
      render_success(true)
    end


    setup_authorization_header(:available_stream_period)
    swagger_api :available_stream_period do |api|
      summary 'calculate stream-able period'
      param :path, :id, :string, :required, 'user id'
    end
    def available_stream_period
      render json: {
        period: @user.available_stream_period
      }
    end


    # label functions
    setup_authorization_header(:send_label_request)
    swagger_api :send_label_request do |api|
      summary 'label - send a label request to a user'
      param :path, :id, :string, :required
    end
    def send_label_request
      authorize @user
      render_error 'You are blocked by this user', :unprocessable_entity and return if @user.block_list.include?(current_user.id)

      relation = Relation.insert(
        host: current_user,
        client: @user,
        context: 'label',
        status: Relation.statuses[:pending]
      )
      render_error 'Exist a pending/approved request', :unprocessable_entity and return if relation === false

      message_body = "#{current_user.display_name} wants to add you to their label roster"
      attachment = Attachment.new(
        attachment_type: Attachment.attachment_types[:label_user],
        attachable_type: @user.class.name,
        attachable_id: @user.id,
        repost_price: 0,
        payment_customer_id: nil,
        payment_token: nil,
        status: Attachment.statuses[:pending]
      )
      receipt = Util::Message.send(current_user, @user, message_body, nil, attachment)

      render_success true
    end


    setup_authorization_header(:remove_label)
    swagger_api :remove_label do |api|
      summary 'label - remove a user from label roster'
      param :path, :id, :string, :required
    end
    def remove_label
      authorize @user

      host = nil
      client = nil
      if current_user.label?
        host = current_user
        client = @user
      else
        host = @user
        client = current_user
      end

      relation = Relation.find_by(
        host_id: host.id,
        client_id: client.id,
        context: 'label',
      )
      render_error 'Not found a relation', :unprocessable_entity and return unless relation.present?

      case relation.status
        when Relation.statuses[:pending]
          attachment = Attachment.find_pending(
            sender: host,
            receiver: client,
            attachment_type: Attachment.attachment_types[:label_user],
            attachable: client
          )
          attachment.update_attributes(status: Attachment.statuses[:canceled]) if attachment.present?
        when Relation.statuses[:accepted]
          # cancel pending album request
          attachments = Attachment
            .joins("LEFT JOIN mailboxer_notifications t2 ON t2.id = attachments.mailboxer_notification_id "\
              "LEFT JOIN mailboxer_receipts t3 ON t2.id = t3.notification_id")
            .where(
              attachment_type: Attachment.attachment_types[:label_album],
              status: Attachment.statuses[:pending])
            .where("t2.sender_id = ? AND t3.receiver_id = ?", host.id, client.id)
          attachments.update_all(status: Attachment.statuses[:canceled])

          UserAlbum.joins(:album).where(
            user_id: host.id,
            user_type: UserAlbum.user_types[:label],
            albums: { user_id: client.id }
          ).delete_all
      end
      relation.delete

      render_success true
    end


    setup_authorization_header(:accept_label_request)
    swagger_api :accept_label_request do |api|
      summary 'label - accept a label request to a user'
      param :path, :id, :string, :required
    end
    def accept_label_request
      authorize @user

      attachment = Attachment.find_pending(
        sender: @user,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:label_user],
        attachable: current_user
      )
      render_error 'Not found an attachment', :unprocessable_entity and return unless attachment.present?
      attachment.update_attributes(status: Attachment.statuses[:accepted])

      relation = Relation.find_by(
        host_id: @user.id,
        client_id: current_user.id,
        context: 'label',
        status: Relation.statuses[:pending]
      )
      relation.update_attributes(status: Relation.statuses[:accepted])

      render_success true
    end


    setup_authorization_header(:deny_label_request)
    swagger_api :deny_label_request do |api|
      summary 'label - deny a label request to a user'
      param :path, :id, :string, :required
    end
    def deny_label_request
      authorize @user

      attachment = Attachment.find_pending(
        sender: @user,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:label_user],
        attachable: current_user
      )
      render_error 'Not found an attachment', :unprocessable_entity and return unless attachment.present?
      attachment.update_attributes(status: Attachment.statuses[:denied])

      relation = Relation.find_by(
        host_id: @user.id,
        client_id: current_user.id,
        context: 'label',
        status: Relation.statuses[:pending]
      )
      relation.update_attributes(status: Relation.statuses[:denied])

      render_success true
    end


    setup_authorization_header(:share)
    swagger_api :share
      summary 'share album / product'
      param :path, :id, :string, :required
      param :form, 'assoc_type', :string, :required
      param :form, 'assoc_id', :integer, :required
      param :form, 'comment', :string, :required
    end
    def share
      authorization @user
      render_error 'Empty parameters' and return if params[:assoc_type].blank? || params[:assoc_id].blank?
      render_error 'Invalid parameters' and return unless ['Album', 'ShopProduct'].include?(parms[:assoc_type])

      assoc = params[:assoc_type].constantize.find(params[:assoc_id]) rescue nil
      render_error 'Invalid parameters' unless assoc.present?

      comment = params[:comment] || ''
      # if params[:comment].present?
      #   comment = params[:comment]
      # else
      #   if params[:assoc_type] == 'Album'
      #   else
      #   end
      # end

      Activity.insert(
        sender_id: current_user.id,
        receiver_id: @user.id,
        message: comment,
        assoc_type: assoc.class.name,
        assoc_id: assoc.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:share],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:unread]
      )
      Activity.insert(
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: comment,
        assoc_type: assoc.class.name,
        assoc_id: assoc.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:share],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:read]
      )
      render_success true
    end


    # admin functions - don't use inactive, verified for now
    setup_authorization_header(:update_status)
    swagger_api :update_status do |api|
      summary 'admin - change user status'
      param :path, :id, :string, :required, 'user id'
      param :form, :status, :string, :required, 'active, pending, suspended'
    end
    def update_status
      authorize @user
      render_error('You can change the status after user confirm the account', :unprocessable_entity) and return unless @user.active? || @user.pending? || @user.suspended?

      # update approver field
      if params[:status] == 'active' && @user.approver_id.blank? && !@user.listener?
        @user.approver_id = current_user.id
        @user.approved_at = Time.now
      end

      @user.status = User.statuses[params[:status]]
      @user.save
      render_success(true)
    end


    setup_authorization_header(:update_role)
    swagger_api :update_role do |api|
      summary 'admin - assign user role'
      param :path, :id, :string, :required, 'user id'
      param :form, :role, :string, :required, 'admin, moderator, artist, listener'
    end
    def update_role
      authorize @user
      #TODO - consider to following validation in policy
      #TODO - check role according to current_user's role
      role = params[:role].downcase
      render_error('You are not permitted', :unprocessable_entity) and return if ['superadmin', 'admin'].include?(role)
      if role == 'artist'
        @user.update_attributes(
          approver_id: current_user.id,
          approved_at: Time.now,
          request_role: role,
          request_status: User.request_statuses[:accepted]
        )
      end
      @user.apply_role(role)

      @user.reload
      render json: @user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: false,
        include_social_info: true
    end

    private
    def set_user
      @user = User.find_by_slug(params[:id]) || User.find_by_username(params[:id]) || User.find(params[:id])
    end
  end
end
