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
  end
end
