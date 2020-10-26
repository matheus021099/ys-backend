module Api::V1
  class AdminController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :admin, 'admin'

    setup_authorization_header(:users)
    swagger_api :users do |api|
      summary 'get users'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
      param :query, :filter, :string, :optional, 'any, artist, etc'
      param :query, :q, :string, :optional, 'query string'
    end
    def users
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?

      filter = params[:filter] || 'any'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i
      q = params[:q] || '*'

      # users = User.where.not(user_type: [User.user_types[:superadmin], User.user_types[:admin]])
      # case filter
      #   when 'artist'
      #     users = users.where(user_type: User.user_types[:artist])
      #   when 'listener'
      #     users = users.where(user_type: User.user_types[:listener])
      #   when 'moderator'
      #     users = users.where(user_type: User.user_types[:moderator])
      #   when 'brand'
      #     users = users.where(user_type: User.user_types[:brand])
      #   when 'label'
      #     users = users.where(user_type: User.user_types[:label])
      #   when 'suspended'
      #     users = users.where(status: User.statuses[:suspended])
      # end
      # users = users.page(page).per(per_page)

      where = {}
      case filter
        when 'suspended'
          where[:user_type] = {}
          where[:user_type][:not] = ['superadmin', 'admin']
          where[:status] = 'suspended'
        when 'listener', 'artist', 'brand', 'label', 'moderator'
          where[:user_type] = filter
        else
          where[:user_type] = {}
          where[:user_type][:not] = ['superadmin', 'admin']
      end
      ps = {}
      ps = ps.merge(
        fields: [:username, :display_name, :email],
        match: :word_start,
        where: where,
        order: {username: :asc},
        page: page,
        per_page: per_page
      )
      users = User.search(q.presence || '*', ps)

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_social_info: true,
          include_all: true,
        ),
        pagination: pagination(users)
      )
    end


    setup_authorization_header(:signup_users)
    swagger_api :signup_users do |api|
      summary 'get signup users'
      param :query, :filter, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
      param :query, :q, :string, :optional, 'query string'
    end
    def signup_users
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?

      filter = params[:filter] || 'any'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 25).to_i
      q = params[:q] || '*'

      # users = User.where.not(user_type: [User.user_types[:superadmin], User.user_types[:admin]])
      # case filter
      #   when 'co-signed'
      #     users = users.where(
      #       user_type: User.user_types[:listener],
      #       status: User.statuses[:active],
      #       # request_role: ['artist', 'brand', 'label'],
      #       request_status: User.request_statuses[:pending]
      #     ).where.not(inviter_id: nil)
      #   when 'waiting'
      #     users = users.where(
      #       user_type: User.user_types[:listener],
      #       status: User.statuses[:active],
      #       # request_role: ['artist', 'brand', 'label'],
      #       request_status: User.request_statuses[:pending],
      #       inviter_id: nil
      #     )
      #   when 'approved'
      #     users = users.where(request_status: User.request_statuses[:accepted])
      #   when 'denied'
      #     users = users.where(request_status: User.request_statuses[:denied])
      # end
      # users = users.page(page).per(per_page)

      where = {}
      case filter
        when 'co-signed'
          where[:user_type] = User.user_types[:listener]
          where[:status] = User.statuses[:active]
          where[:request_status] = User.request_statuses[:pending]
          where[:inviter_id] = {}
          where[:inviter_id][:not] = nil
        when 'waiting'
          where[:user_type] = User.user_types[:listener]
          where[:status] = User.statuses[:active]
          where[:request_status] = User.request_statuses[:pending]
          where[:inviter_id] = nil
        when 'approved'
          where[:user_type] = {}
          where[:user_type][:not] = ['superadmin', 'admin']
          where[:request_status] = User.request_statuses[:accepted]
        when 'denied'
          where[:user_type] = {}
          where[:user_type][:not] = ['superadmin', 'admin']
          where[:request_status] = User.request_statuses[:denied]
        else
          where[:user_type] = {}
          where[:user_type][:not] = ['superadmin', 'admin']
      end
      ps = {}
      ps = ps.merge(
        fields: [:username, :display_name, :email],
        match: :word_start,
        where: where,
        order: {username: :asc},
        page: page,
        per_page: per_page
      )
      users = User.search(q.presence || '*', ps)

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_social_info: true,
        ),
        pagination: pagination(users)
      )
    end


    setup_authorization_header(:approve_user)
    swagger_api :approve_user do |api|
      summary 'approve user'
      param :form, :user_id, :string, :required
    end
    def approve_user
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      user = User.find(params[:user_id])
      user.update_attributes(
        approver_id: current_user.id,
        approved_at: Time.now,
        request_status: User.request_statuses[:accepted]
      )
      user.apply_role user.request_role
      user.reload

      message_body = "Hi, #{user.username} your account has been verified.<br><br>" \
        'To accept payments you must connect to Stripe.com by logging in and visiting Settings > Bank Details on the web/desktop.<br>' \
        'If you are already logged in, please sign out then login to update your account status.<br><br>' \
        'Regards, YouSound Team'
      # case user.request_role
      #   when 'brand'
      #     message_body = "Welcome to YouSound!<br><br>" \
      #       "Brands are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>" \
      #       "You can earn revenue by reposting content from Verified Users via Repost Requests.<br><br>" \
      #       "As a Brand you can sell your products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>" \
      #       "To accept payments, connect to Stripe: <a href='https://yousound.com/settings#bank-details'>Settings > Bank Details</a>"
      #   when 'label'
      #     message_body = "Welcome to YouSound!<br><br>" \
      #       "Labels are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>" \
      #       "You can earn revenue by reposting content from Verified Users via Repost Requests.<br><br>" \
      #       "As a Label you can request artists and their albums to be apart of your roster, sell products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>" \
      #       "To accept payments, connect to Stripe: <a href='https://yousound.com/settings#bank-details'>Settings > Bank Details</a>"
      #   else
      #     message_body = "Welcome to YouSound!<br><br>" \
      #       "Artists are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>" \
      #       "You have the ability to help Artists, Brands, and Labels reach more users. You can also earn revenue by reposting content from Verified Users via Repost Requests.<br><br>" \
      #       "As an artist you can upload albums, sell products, collaborate on albums with other artists, collaborate on products with other artists, brands, and labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>" \
      #       "To accept payments, connect to Stripe: <a href='https://yousound.com/settings#bank-details'>Settings > Bank Details</a>"
      # end

      sender = User.public_relations_user
      receiver = user
      if sender.present?
        Util::Message.send(sender, receiver, message_body)
      end

      ApplicationMailer.to_requester_approved_email(current_user, user).deliver

      render json: user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: false,
        include_social_info: true
    end


    setup_authorization_header(:deny_user)
    swagger_api :deny_user do |api|
      summary 'deny user'
      param :form, :user_id, :string, :required
      param :form, :denial_reason, :string, :required
      param :form, :denial_description, :string, :required
    end
    def deny_user
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      user = User.find(params[:user_id])
      user.apply_role User.user_types[:listener] unless user.listener?
      user.update_attributes(
        denial_reason: params[:denial_reason],
        denial_description: params[:denial_description],
        approver_id: current_user.id,
        approved_at: Time.now,
        request_status: User.request_statuses[:denied]
      )

      ApplicationMailer.to_requester_denied_email(current_user, user).deliver
      render_success true
    end


    setup_authorization_header(:toggle_view_direct_messages)
    swagger_api :toggle_view_direct_messages do |api|
      summary 'toggle view direct messages feature for moderators'
      param :form, :user_id, :string, :required
    end
    def toggle_view_direct_messages
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
      user = User.find(params[:user_id])
      user.update_attributes(
        enabled_view_direct_messages: !user.enabled_view_direct_messages
      )
      render_success true
    end


    setup_authorization_header(:toggle_live_video)
    swagger_api :toggle_live_video do |api|
      summary 'toggle live video feature for a user'
      param :form, :user_id, :string, :required
    end
    def toggle_live_video
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      user = User.find(params[:user_id])
      user.update_attributes(
        enabled_live_video: !user.enabled_live_video
      )
      render_success true
    end


    setup_authorization_header(:toggle_live_video_free)
    swagger_api :toggle_live_video_free do |api|
      summary 'toggle live video free for a user'
      param :form, :user_id, :string, :required
    end
    def toggle_live_video_free
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      user = User.find(params[:user_id])
      user.stream.remove if user.stream && user.stream.running?

      user.update_attributes(
        # free_streamed_time: user.enabled_live_video_free ? 0 : user.free_streamed_time,
        free_streamed_time: 0,
        enabled_live_video_free: !user.enabled_live_video_free
      )
      render_success true
    end


    setup_authorization_header(:albums)
    swagger_api :albums do |api|
      summary 'get albums'
      param :query, :statuses, :string, :optional, 'any, published, privated, pending, collaborated'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
      param :query, :q, :string, :optional, 'query string'
    end
    def albums
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      statuses = params[:statuses].present? ? params[:statuses].split(',').map(&:strip) : ['any']
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i
      q = params[:q] || '*'

      ps = {}
      where = {slug: {not: nil}}
      where[:status] = statuses unless statuses.include?('any')
      ps = ps.merge(
        fields: [:name, :description, :owner_username, :owner_display_name],
        match: :word_start,
        where: where,
        order: {created_at: :desc},
        page: page,
        per_page: per_page
      )
      albums = Album.search(q.presence || '*', ps)

      render_success(
        albums: ActiveModel::Serializer::CollectionSerializer.new(
          albums,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(albums)
      )
    end


    setup_authorization_header(:products)
    swagger_api :products do |api|
      summary 'get products'
      param :query, :statuses, :string, :optional, 'any, published, privated, pending, collaboration'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def products
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      statuses = params[:statuses].present? ? params[:statuses].split(',').map(&:strip) : ['any']
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      # products = ShopProduct.where.not(status: Album.statuses[:deleted]).order(created_at: :desc)
      products = ShopProduct.all.order(created_at: :desc)
      products = products.where(status: statuses) unless statuses.include?('any')
      products = products.page(page).per(per_page)

      render_success(
        products: ActiveModel::Serializer::CollectionSerializer.new(
          products,
          serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(products)
      )
    end


    setup_authorization_header(:streams)
    swagger_api :stream do |api|
      summary 'get streams'
      params :query, :q, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def streams
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
      q = params[:q] || ''
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      streams = Stream.includes(:user).where('name ILIKE ?', "%#{q.downcase}%")
        .order("streams.status != 'running', streams.created_at ASC")
      streams = streams.page(page).per(per_page)

      render_success(
        streams: streams.as_json(
          only: [ :id, :name, :total_viewers, :view_price, :status, :created_at ],
          methods: :broadcast_time,
          include: {
            user: {
              only: [ :id, :username, :avatar]
            },
            genre: {
              only: [ :id, :name]
            }
          }
        ),
        pagination: pagination(streams)
      )
    end


    setup_authorization_header(:send_global_message)
    swagger_api :send_global_message do |api|
      summary 'send global message'
      param :form, :message, :string, :required
    end
    def send_global_message
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?

      message_body = params[:message].strip rescue ''
      render_error 'No message', :unprocessable_entity and return if message_body.blank?

      MessageBroadcaster.perform_async(current_user.id, message_body)

      render_success true
    end


    setup_authorization_header(:global_stats)
    swagger_api :global_stats do |api|
      summary 'global stats'
      param :query, :start_date, :string, :optional
      param :query, :end_date, :string, :optional
    end
    def global_stats
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
      start_date = params[:start_date].present? ? params[:start_date].to_datetime : Time.parse('2015-01-01')
      end_date = params[:end_date].present? ? params[:end_date].to_datetime : Time.current
      # total_users = (ActiveRecord::Base.connection.exec_query(
      #   "SELECT COUNT(1) AS total_users "\
      #   "FROM users"
      # ).first)['total_users']
      total_users = User.where(
        user_type: [
          User.user_types[:listener],
          User.user_types[:artist],
          User.user_types[:brand],
          User.user_types[:label],
          User.user_types[:moderator]
        ]
      ).size
      login_users = Activity.where(
        action_type: Activity.action_types[:signin]
      ).where('created_at >= ? AND created_at <= ?', start_date, end_date).size
      signup_listener_users = User.where('user_type = ? AND users.created_at >= ? AND users.created_at <= ?',
        User.user_types[:listener],
        start_date,
        end_date
      ).size
      signup_artist_users = User.where('user_type = ? AND users.created_at >= ? AND users.created_at <= ?',
        User.user_types[:artist],
        start_date,
        end_date
      ).size
      signup_brand_users = User.where('user_type = ? AND users.created_at >= ? AND users.created_at <= ?',
        User.user_types[:brand],
        start_date,
        end_date
      ).size
      signup_label_users = User.where('user_type = ? AND users.created_at >= ? AND users.created_at <= ?',
        User.user_types[:label],
        start_date,
        end_date
      ).size

      # uploaded_albums = Feed.joins('LEFT JOIN albums ON albums.id = feeds.assoc_id').where(
      #   'feeds.consumer_id = feeds.publisher_id'
      # ).where(
      #   feed_type: Feed.feed_types[:release],
      #   assoc_type: 'Album',
      #   albums: { album_type: Album.album_types[:album] }
      # ).where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size
      uploaded_albums = Album.where(released: true, album_type: Album.album_types[:album])
        .where('released_at >= ? AND released_at <= ?', start_date, end_date).size

      downloaded_albums = Feed.joins('LEFT JOIN albums ON albums.id = feeds.assoc_id')
        .where('feeds.consumer_id = feeds.publisher_id')
        .where(
          feed_type: Feed.feed_types[:download],
          assoc_type: 'Album',
          albums: { album_type: Album.album_types[:album] }
        )
        .where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size

      # played_albums = Feed.joins('LEFT JOIN albums ON albums.id = feeds.assoc_id')
      #   .where('feeds.consumer_id = feeds.publisher_id')
      #   .where(
      #     feed_type: Feed.feed_types[:play],
      #     assoc_type: 'Album',
      #     albums: { album_type: Album.album_types[:album] }
      #   )
      #   .where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size
      played_albums = Activity
        .where(
          action_type: Activity.action_types[:play],
          assoc_type: 'Album'
        )
        .where('activities.created_at >= ? AND activities.created_at <= ?', start_date, end_date)
        .group(:assoc_id).count.size

      # created_playlists = Feed.joins('LEFT JOIN albums ON albums.id = feeds.assoc_id').where(
      #   'feeds.consumer_id = feeds.publisher_id'
      # ).where(
      #   feed_type: Feed.feed_types[:release],
      #   assoc_type: 'Album',
      #   albums: { album_type: Album.album_types[:playlist] }
      # ).where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size
      created_playlists = Album.where(released: true, album_type: Album.album_types[:playlist])
        .where('created_at >= ? AND created_at <= ?', start_date, end_date).size

      # uploaded_products = Feed.joins('LEFT JOIN shop_products ON shop_products.id = feeds.assoc_id').where(
      #   'feeds.consumer_id = feeds.publisher_id'
      # ).where(
      #   feed_type: Feed.feed_types[:release],
      #   assoc_type: 'ShopProduct',
      #   albums: { album_type: Album.album_types[:album] }
      # ).where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size
      uploaded_products = Feed.where('feeds.consumer_id = feeds.publisher_id')
        .where(feed_type: Feed.feed_types[:release], assoc_type: 'ShopProduct')
        .where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size

      sold_products = ShopItem.where.not(
        order_id: nil
      ).where('created_at >= ? AND created_at <= ?', start_date, end_date).sum(:quantity)

      reposted_albums = Feed.where('feeds.consumer_id = feeds.publisher_id')
        .where(feed_type: Feed.feed_types[:repost], assoc_type: 'Album')
        .where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size

      reposted_products = Feed.where('feeds.consumer_id = feeds.publisher_id')
        .where(feed_type: Feed.feed_types[:repost], assoc_type: 'ShopProduct')
        .where('feeds.created_at >= ? AND feeds.created_at <= ?', start_date, end_date).size

      donations_count = Payment.where(payment_type: Payment.payment_types[:donate])
        .where('payments.created_at >= ? AND payments.created_at <= ?', start_date, end_date).size
      donations_revenue = Payment.where(payment_type: Payment.payment_types[:donate])
        .where('payments.created_at >= ? AND payments.created_at <= ?', start_date, end_date).sum(:sent_amount)

      chat_users = 0

      free_stream_seconds = Activity.where(action_type: Activity.action_types[:free_host_stream])
        .where('activities.created_at >= ? AND activities.created_at <= ?', start_date, end_date)
        .select(:message).pluck(:message).inject(0){|s, m| s += m.to_i}
      demand_stream_seconds = Activity.where(action_type: Activity.action_types[:demand_host_stream])
        .where('activities.created_at >= ? AND activities.created_at <= ?', start_date, end_date)
        .select(:message).pluck(:message).inject(0){|s, m| s += m.to_i}

      result = ActiveRecord::Base.connection.execute("""
        SELECT taggings.tag_id, count(1) AS count FROM feeds
        INNER JOIN taggings ON feeds.assoc_id = taggings.taggable_id
        WHERE feeds.consumer_id = feeds.publisher_id
          AND feeds.feed_type = 'download'
          AND feeds.assoc_type = 'Album'
          AND feeds.updated_at >= '#{start_date}' AND feeds.updated_at <= '#{end_date}'
          AND taggings.context = 'genres'
        GROUP BY taggings.tag_id
        ORDER BY count DESC
        LIMIT 5
      """)
      tag_ids = result.to_a.pluck('tag_id')
      top_5_downloaded_genres = Genre.joins("LEFT JOIN tags ON genres.id = CAST(tags.name as int)").where(tags: {id: tag_ids})

      # genre_sql = <<-SQL
      #   SELECT taggings.tag_id, count(1) AS count FROM feeds
      #   INNER JOIN taggings ON feeds.assoc_id = taggings.taggable_id
      #   WHERE feeds.consumer_id = feeds.publisher_id
      #     AND feeds.feed_type = 'play'
      #     AND feeds.assoc_type = 'Album'
      #     AND feeds.updated_at >= '#{start_date}' AND feeds.updated_at <= '#{end_date}'
      #     AND taggings.context = 'genres'
      #   GROUP BY taggings.tag_id
      #   ORDER BY count DESC
      #   LIMIT 5
      # SQL
      genre_sql = <<-SQL
        SELECT taggings.tag_id, count(1) AS count FROM (
          SELECT DISTINCT ON (activities.sender_id) * FROM activities
          WHERE activities.sender_id = activities.receiver_id
            AND activities.action_type = 'play'
            AND activities.assoc_type = 'Album'
            AND activities.created_at >= '#{start_date}' AND activities.created_at <= '#{end_date}'
        ) t1
        INNER JOIN taggings ON t1.assoc_id = taggings.taggable_id
        WHERE taggings.context = 'genres'
        GROUP BY taggings.tag_id
        ORDER BY count DESC
        LIMIT 5
      SQL
      result = ActiveRecord::Base.connection.execute(genre_sql)
      tag_ids = result.to_a.pluck('tag_id')
      top_5_played_genres = Genre.joins("LEFT JOIN tags ON genres.id = CAST(tags.name as int)").where(tags: {id: tag_ids})

      cancelled_accounts = User.where(status: User.statuses[:deleted])
        .where('users.updated_at >= ? AND users.updated_at <= ?', start_date, end_date).size

      states = {
        # total_users: user['total_users'],
        start_date: start_date,
        end_date: end_date,
        total_users: total_users,
        login_users: login_users,
        current_users: 0,
        signup_listener_users: signup_listener_users,
        signup_artist_users: signup_artist_users,
        signup_brand_users: signup_brand_users,
        signup_label_users: signup_label_users,
        uploaded_albums: uploaded_albums,
        downloaded_albums: downloaded_albums,
        played_albums: played_albums,
        created_playlists: created_playlists,
        uploaded_products: uploaded_products,
        sold_products: sold_products,
        reposted_albums: reposted_albums,
        reposted_products: reposted_products,
        # reposted_requests: 0,
        # reposted_requests_revenue: 0,
        donations_count: donations_count,
        donations_revenue: donations_revenue,
        chat_users: 0,
        free_stream_seconds: free_stream_seconds,
        demand_stream_seconds: demand_stream_seconds,
        top_5_downloaded_genres: ActiveModel::Serializer::CollectionSerializer.new(top_5_downloaded_genres, serializer: GenreSerializer),
        top_5_played_genres: ActiveModel::Serializer::CollectionSerializer.new(top_5_played_genres, serializer: GenreSerializer),
        cancelled_accounts: cancelled_accounts,
      }
      render json: states
    end
  end
end
