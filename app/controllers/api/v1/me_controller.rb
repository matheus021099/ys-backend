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
      param :form, :per_page, :integer, :optional, '10, 20, etc. default is 10'
      params :form, :stripe_connected, :boolean, optional
    end
    def mutual_users
      page = params[:page] || 1
      per_page = params[:per_page] || 10

      requrie_stripe_connected = ActiveModel::Type::Boolean.new.cast(params[:stripe_connected]) rescue false

      users = current_user.mutual_users(requrie_stripe_connected).page(page).per(per_page)

      render_success(
        users: ActiveModelSerializers::SerializableResource.new(
          users,
          each_serializer: UserSerializer1,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(users)
      )
    end
  end
end
