module Api::V1
  class ProfileController < ApiController
    skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :authenticate_token
    before_action :set_user

    swagger_controller :profile, 'Public Profile'


    swagger_api :artists do |api|
      summary 'artists'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def artists
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      users = nil
      if @user.label?
        users = User.joins("RIGHT JOIN relations ON users.id = relations.client_id").where(
          relations: {
            host_id: @user.id,
            status: Relation.statuses[:accepted]
          }
        ).page(page).per(per_page)
      else
        users = User.where(id: nil).page(page).per(per_page)
      end

      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(users)
      )
    end


    swagger_api :catalog do |api|
      summary 'catalog'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def catalog
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      albums = nil
      if @user.label?
        albums = Album.joins(:user_albums).where(
          users_albums: {
            user_id: @user.id,
            user_type: UserAlbum.user_types[:label],
            status: UserAlbum.statuses[:accepted]
          }
        ).page(page).per(per_page)
      else
        albums = Album.where(id: nil).page(page).per(per_page)
      end

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


    swagger_api :songs do |api|
      summary 'songs'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :filter, :string, :optional, 'new, pouplar'
      param :form, :genre, :string, :optional, 'any, genre name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def songs
      filter = params[:filter] || 'new'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      albums = @user.album_query(filter, genre).includes(album_tracks: :track).page(page).per(per_page)

      render_success Panko::Response.new(
        albums: Panko::ArraySerializer.new(
          albums, {
            each_serializer: AlbumSerializer1,
            scope: OpenStruct.new(current_user: current_user)
          }
        ),
        pagination: pagination(albums)
      )
    end


    swagger_api :merch do |api|
      summary 'merch'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def merch
      category = params[:category] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      # products = @user.products.page(page).per(per_page)
      products = ShopProduct.joins(:user_products)
        .where(
          users_products: { user_id: @user.id },
          stock_status: ShopProduct.stock_statuses[:active],
          status: [ShopProduct.statuses[:published], ShopProduct.statuses[:collaborated]]
        )
        .where.not(
          show_status: ShopProduct.show_statuses[:show_only_stream]
        )
        .order(created_at: :desc).page(page).per(per_page)

      render_success(
        products: ActiveModel::Serializer::CollectionSerializer.new(
          products,
          serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user),
          include_collaborators: true,
          include_collaborators_user: true
        ),
        pagination: pagination(products)
      )
    end


    swagger_api :downloaded do |api|
      summary 'downloaded'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def downloaded
      filter = params[:filter] || 'new'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      albums = @user.download_query(filter, genre).page(page).per(per_page)

      render_success Panko::Response.new(
        albums: Panko::ArraySerializer.new(
          albums, {
            each_serializer: AlbumSerializer1,
            scope: OpenStruct.new(current_user: current_user)
          }
        ),
        pagination: pagination(albums)
      )
    end


    swagger_api :reposted do |api|
      summary 'reposted'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def reposted
      filter = params[:filter] || 'new'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      feeds = @user.repost_query(filter, genre).page(page).per(per_page)

      render_success Panko::Response.new(
        feeds: Panko::ArraySerializer.new(
          feeds, {
            each_serializer: FeedSerializer1,
            scope: OpenStruct.new(current_user: current_user)
          }
        ),
        pagination: pagination(feeds)
      )
    end


    swagger_api :playlists do |api|
      summary 'playlists'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :filter, :string, :optional, 'new, pouplar'
      param :form, :genre, :string, :optional, 'any, genre name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def playlists
      filter = params[:filter] || 'new'
      genre = params[:genre] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      albums = @user.playlist_query(filter, genre).page(page).per(per_page)

      render_success Panko::Response.new(
        albums: Panko::ArraySerializer.new(
          albums, {
            each_serializer: AlbumSerializer1,
            scope: OpenStruct.new(current_user: current_user)
          }
        ),
        pagination: pagination(albums)
      )
    end


    swagger_api :sample_followings do |api|
      summary 'followings have albums cleared to sample'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :form, :filter, :string, :optional, 'any, listener, artist'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '10, 50, 100 etc. default is 50'
      param :path, :id, :string, :required, 'user id or slug'
    end
    def sample_followings
      filter = params[:filter] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 50

      users = @user.sample_following_query
      users = users.page(page).per(per_page)
      render_success(
        users: ActiveModelSerializers::SerializableResource.new(
          users,
          each_serializer: UserSerializer1,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(users)
      )
    end


    swagger_api :followings do |api|
      summary 'followings'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :filter, :string, :optional, 'any, listener, artist'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def followings
      filter = params[:filter] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      users = @user.following_query(filter)
      users = users.page(page).per(per_page)
      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(users)
      )
    end


    swagger_api :followers do |api|
      summary 'followers'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'user id or slug'
      param :form, :filter, :string, :optional, 'any, listener, artist'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def followers
      filter = params[:filter] || 'any'
      page = params[:page] || 1
      per_page = params[:per_page] || 24

      users = @user.follower_query(filter)
      users = users.page(page).per(per_page)
      render_success(
        users: ActiveModel::Serializer::CollectionSerializer.new(
          users,
          serializer: UserSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(users)
      )
    end

    private
    def set_user
      @user = User.find_by_slug(params[:id]) || User.find(params[:id])
    end
  end
end
