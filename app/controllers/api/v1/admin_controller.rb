module Api::V1
  class AdminController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :admin, 'admin'

    setup_authorization_header(:signup_users)
    swagger_api :signup_users do |api|
      summary 'get signup users'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def signup_users
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      exclude_ids = User.with_any_role(:superadmin, :admin).pluck(:id)
      exclude_ids << current_user.id
      users = User.where.not(id: exclude_ids, request_status: nil)
      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_social_info: true,
        ),
        # pagination: pagination(users)
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

      message_body = ''
      case user.request_role
        when 'brand'
          message_body = "Welcome to YouSound!<br><br>Brands are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You can earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with your friends, and build relationships with the YouSound community.<br><br>As a Brand you can sell your products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
        when 'label'
          message_body = "Welcome to YouSound!<br><br>Labels are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You can earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with friends & build relationships within the YouSound community.<br><br>As a Label you can request artists and their albums to be apart of your roster, sell products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
        else
          message_body = "Welcome to YouSound!<br><br>Artists are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You have the ability to help Artists, Brands, and Labels reach more users. You can also earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with your friends, and build relationships with the YouSound community.<br><br>As an artist you can upload albums, sell products, collaborate on albums with other artists, collaborate on products with other artists, brands, and labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
      end

      sender = User.admin
      receiver = user
      receipt = Util::Message.send(sender, receiver, message_body)
      conversation = receipt.conversation

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
      user.apply_role :listener unless user.listener?
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
      param :query, :statuses, :string, :optional, 'any, published, privated, pending, collaboration'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def albums
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      statuses = params[:statuses].present? ? params[:statuses].split(',').map(&:strip) : ['any']
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      albums = Album.where.not(status: Album.statuses[:deleted]).order(created_at: :desc)
      albums = albums.where(status: statuses) unless statuses.include?('any')
      albums = albums.page(page).per(per_page)

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

      products = ShopProduct.where.not(status: Album.statuses[:deleted]).order(created_at: :desc)
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
      total_users = User.with_any_role(:listener, :artist, :brand, :label).size
      login_users = Activity.where(
        action_type: Activity.action_types[:signin]
      ).where('created_at >= ? AND created_at <= ?', start_date, end_date).size
      signup_listener_users = User.with_role(:listener).where(
        'users.created_at >= ? AND users.created_at <= ?', start_date, end_date
      ).size
      signup_artist_users = User.with_role(:artist).where(
        'users.created_at >= ? AND users.created_at <= ?', start_date, end_date
      ).size
      signup_brand_users = User.with_role(:brand).where(
        'users.created_at >= ? AND users.created_at <= ?', start_date, end_date
      ).size
      signup_label_users = User.with_role(:label).where(
        'users.created_at >= ? AND users.created_at <= ?', start_date, end_date
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
