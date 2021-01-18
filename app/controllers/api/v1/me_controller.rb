module Api::V1
  class MeController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :me, 'Features for Current User'

    setup_authorization_header(:stripe_email)
    swagger_api :stripe_email do |api|
      summary 'get connected stripe email'
    end
    def stripe_email
      stripe_account = Stripe::Account.retrieve(current_user.payment_account_id) rescue {}

      render json: {
        email: stripe_account['email'] || ''
      }
    end


    setup_authorization_header(:mutual_users)
    swagger_api :mutual_users do |api|
      summary 'get mutual users'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '-1, 10, 20, etc. default is 10'
      params :form, :stripe_connected, :boolean, optional
    end
    def mutual_users
      page = params[:page] || 1
      per_page = params[:per_page] || 10
      requrie_stripe_connected = ActiveModel::Type::Boolean.new.cast(params[:stripe_connected]) rescue false

      users = current_user.mutual_users(requrie_stripe_connected)
      paginationJson = {}
      if per_page > 0
        users = users.page(page).per(per_page)
        paginationJson = pagination(users)
      end

      render_success(
        users: ActiveModelSerializers::SerializableResource.new(
          users,
          each_serializer: UserSerializer1,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: paginationJson
      )
    end


    setup_authorization_header(:connect_stripe)
    swagger_api :connect_stripe do |api|
      summary 'connect stripe'
      param :form, :code, :string, :required, 'code'
      # param :form, 'user[payment_provider]', :string, :required
      # param :form, 'user[payment_account_id]', :string, :required
      # param :form, 'user[payment_account_type]', :string, :required, 'standalone, etc'
      # param :form, 'user[payment_publishable_key]', :string, :required
      # param :form, 'user[payment_access_code]', :string, :required
    end
    def connect_stripe
      uri = URI.parse("https://connect.stripe.com/oauth/token")
      response = Net::HTTP.post_form(uri, {
        "client_secret": ENV['STRIPE_SECRET_KEY'],
        "code": params[:code],
        "grant_type": "authorization_code"
      })
      result = JSON.parse(response.body)

      render_error result['error_description'], :unprocessable_entity and return if result['error'].present?

      stripe_account = Stripe::Account.retrieve(result['stripe_user_id']) rescue {}
      render_error 'Stripe account is not accessible', :unprocessable_entity and return if stripe_account['id'].blank?

      current_user.update_attributes(
        payment_provider: 'stripe',
        payment_account_id: result['stripe_user_id'],
        payment_account_type: 'standalone',
        payment_publishable_key: result['stripe_publishable_key'],
        payment_access_code: result['access_token']
      )

      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: false
    end


    setup_authorization_header(:disconnect_stripe)
    swagger_api :disconnect_stripe do |api|
      summary 'disconnect stripe'
    end
    def disconnect_stripe
      current_user.disconnect_stripe

      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true,
        include_social_info: false
    end


    setup_authorization_header(:video_attach_albums)
    swagger_api :video_attach_albums do |api|
      summary 'albums to attach the live video'
    end
    def video_attach_albums
      albums = current_user.stream_attach_albums_query || []
      render json: ActiveModel::Serializer::CollectionSerializer.new(
        albums,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user)
      )
    end


    setup_authorization_header(:video_attach_products)
    swagger_api :video_attach_products do |api|
      summary 'products to attach the live video'
    end
    def video_attach_products
      products = current_user.stream_attach_products_query || []
      render json: ActiveModel::Serializer::CollectionSerializer.new(
        products,
        serializer: ShopProductSerializer,
        scope: OpenStruct.new(current_user: current_user)
      )
    end
  end
end
