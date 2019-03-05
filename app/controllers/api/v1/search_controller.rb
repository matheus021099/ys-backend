module Api::V1
  class SearchController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    skip_before_action :authenticate_token!, only: [:search_landing]
    before_action :authenticate_token

    swagger_controller :search, 'search'

    setup_authorization_header(:search_stream_v2)
    swagger_api :search_stream_v2 do |api|
      summary 'search stream v2'
      param :form, :filter, :string, :optional, 'any, uploaded, reposted, downloaded, playlist, merch'
      # param :form, :genre, :string, :optional, 'any, Alt Rock, genre name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def search_stream_v2
      filter = params[:filter] || 'any'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 4
      users = current_user.feed_query_v2(filter, genre).page(page).per(per_page)
      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_recent: filter === 'any',
          include_recent_uploaded: filter === 'uploaded',
          include_recent_reposted: filter === 'reposted',
          include_recent_downloaded: filter === 'downloaded',
          include_recent_playlist: filter === 'playlist',
          include_recent_merch: filter === 'merch',
        ),
        pagination: pagination(users)
      )
    end


    setup_authorization_header(:search_stream)
    swagger_api :search_stream do |api|
      summary 'search stream'
      param :form, :filter, :string, :optional, 'any, downloaded, reposted, uploaded, playlist, merch'
      # param :form, :genre, :string, :optional, 'any, Alt Rock, genre name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def search_stream
      filter = params[:filter] || 'any'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24
      feeds = current_user.feed_query(filter, genre).page(page).per(per_page)
      render_success(
        feeds: ActiveModel::Serializer::CollectionSerializer.new(
          feeds,
          serializer: FeedSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_publisher: true
        ),
        pagination: pagination(feeds)
      )
    end


    setup_authorization_header(:search_discover)
    swagger_api :search_discover do |api|
      summary 'search discover'
      param :form, :filter, :string, :optional, 'any, merch, new, popular, playlist, recommended'
      param :form, :genre, :string, :optional, 'any, Alt Rock, genre name'
      param :form, :category, :string, :optional, 'any, Tee, Shirt, shop_category name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
      param :form, :q, :string, :optional, '*, query string'
    end
    def search_discover
      q = params[:q] || '*'
      filter = params[:filter] || 'merch'
      genre = params[:genre] || 'any'
      category = params[:category] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      if filter == 'any'
        albums_recommended = User.explore_query(q, 'recommended', genre, {page: page, per_page: per_page}, current_user)
        albums_new = User.explore_query(q, 'new', genre, {page: page, per_page: per_page}, current_user)
        # albums_popular = User.explore_query(q, 'popular', genre, {page: page, per_page: per_page}, current_user)
        playlists = User.explore_query(q, 'playlist', genre, {page: page, per_page: per_page}, current_user)
        products = ShopProduct.explore_query(category, {page: page, per_page: per_page}, current_user)

        render_success(
          recommended: ActiveModel::Serializer::CollectionSerializer.new(
            albums_recommended,
            serializer: AlbumSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          new: ActiveModel::Serializer::CollectionSerializer.new(
            albums_new,
            serializer: AlbumSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          # popular: albums_popular,
          playlist: ActiveModel::Serializer::CollectionSerializer.new(
            playlists,
            serializer: AlbumSerializer,
            scope: OpenStruct.new(current_user: current_user)
          ),
          merch: ActiveModel::Serializer::CollectionSerializer.new(
            products,
            serializer: ShopProductSerializer,
            scope: OpenStruct.new(current_user: current_user),
            include_collaborators: true,
            include_collaborators_user: true
          ),
        )
      elsif filter == 'merch'
        products = ShopProduct.explore_query(category, {page: page, per_page: per_page}, current_user)
        # categories = ShopCategory.all.pluck(:name)
        categories = ShopProduct.categories_query(current_user).pluck(:name)
        render_success(
          products: ActiveModel::Serializer::CollectionSerializer.new(
            products,
            serializer: ShopProductSerializer,
            scope: OpenStruct.new(current_user: current_user),
            include_collaborators: true,
            include_collaborators_user: true
          ),
          pagination: pagination(products),
          categories: categories
        )
      else
        albums = User.explore_query(q, filter, genre, {page: page, per_page: per_page}, current_user)
        # genres = albums.map { |track| track.tags }.flatten.uniq.map { |tag| tag.name }.select { |tag_name| tag_name.start_with?('#') }.sort_by! { |genre| genre.downcase }

        render_success(
          albums: ActiveModel::Serializer::CollectionSerializer.new(
            albums,
            serializer: AlbumSerializer,
            scope: OpenStruct.new(current_user: current_user),
            include_collaborators: true,
            include_collaborators_user: true
          ),
          pagination: pagination(albums)
        )
      end
    end


    setup_authorization_header(:search_global)
    swagger_api :search_global do |api|
      summary 'search global'
      param :form, :q, :string, :optional
    end
    def search_global
      q = params[:q]
      limit = 10
      users = User.search(
        q.presence || '*',
        fields: [:email, :username, :display_name],
        match: :word_start,
        where: {status: 'active'},
        limit: limit
      )
      albums_all = Album.search(
        q.presence || '*',
        fields: [:name, :description, :owner_username, :owner_display_name],
        match: :word_start,
        where: {status: ['published', 'collaborated'], slug: {not: nil}},
        limit: limit
      )#, load: false)
      albums = albums_all.select{|a| a.album_type == 'album'}
      playlists = albums_all.select{|a| a.album_type == 'playlist'}
      products = ShopProduct.search(
        q.presence || '*',
        fields: [:name, :description, :merchant_username, :merchant_display_name],
        match: :word_start,
        where: {status: ['published', 'collaborated'], stock_status: 'active', show_status: 'show_all'},
        includes: [:merchant, :category, :variants, :shipments, :covers, :user_products],
        limit: limit
      )
      streams = Stream.where(status: Stream.statuses[:running]).limit(limit)
      streams = streams.where('name ILIKE ?', "%#{q.downcase}%") if q.presence

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        albums: ActiveModel::Serializer::CollectionSerializer.new(
          albums,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        playlists: ActiveModel::Serializer::CollectionSerializer.new(
          playlists,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        products: ActiveModel::Serializer::CollectionSerializer.new(
          products,
          serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        streams: ActiveModel::Serializer::CollectionSerializer.new(
          streams,
          serializer: StreamSerializer,
          scope: OpenStruct.new(current_user: current_user)
        )
      )
    end

    setup_authorization_header(:search_landing)
    swagger_api :search_landing do |api|
      summary 'search landing'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :form, :seed, :float, :optional
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, 'default is 5'
    end
    def search_landing
      page = params[:page] || 1
      per_page = params[:per_page] || 5
      seed = params[:seed].to_f rescue rand()

      seed_val = ActiveRecord::Base.connection.quote(seed)

      # a1 = Album.order("RANDOM()").first
      # albums = Album.search('*', where: {status: ['published', 'collaborated'], album_type: 'album', slug: {not: nil}}, limit: per_page)
      ActiveRecord::Base.connection.execute("select setseed(#{seed_val})")
      albums = Album.where(
        status: [Album.statuses[:published], Album.statuses[:collaborated]],
        album_type: Album.album_types[:album]
      ).order("random()").page(page).per(per_page)

      albums = albums.where.not(id: current_user.blocked_album_ids) unless current_user.blank?

      ActiveRecord::Base.connection.execute("select setseed(#{seed_val})")
      playlists = Album.where(
        status: [Album.statuses[:published], Album.statuses[:collaborated]],
        album_type: Album.album_types[:playlist]
      ).order("random()").page(page).per(per_page)

      ActiveRecord::Base.connection.execute("select setseed(#{seed_val})")
      products = ShopProduct.includes(:merchant, :category, :variants, :shipments, :covers, :user_products).where(
        status: [ShopProduct.statuses[:published], ShopProduct.statuses[:collaborated]],
        stock_status: ShopProduct.stock_statuses[:active],
        show_status: ShopProduct.show_statuses[:show_all]
      ).order("random()").page(page).per(per_page)

      ActiveRecord::Base.connection.execute("select setseed(#{seed_val})")
      streams = Stream.order("random()").page(page).per(per_page)

      render_success(
        albums: ActiveModel::Serializer::CollectionSerializer.new(
          albums,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        playlists: ActiveModel::Serializer::CollectionSerializer.new(
          playlists,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        products: ActiveModel::Serializer::CollectionSerializer.new(
          products,
          serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        streams: ActiveModel::Serializer::CollectionSerializer.new(
          streams,
          serializer: StreamSerializer,
          scope: OpenStruct.new(current_user: current_user)
        )
      )
    end
  end
end
