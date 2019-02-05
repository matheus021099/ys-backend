module Api::V1
  class TwitterController < ApiController
    skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :twitter, "Twitter"

    swagger_api :request_token do |api|
      summary 'get request token for twitter'
      param :form, :oauth_callback, :string, :required
    end
    def request_token
      skip_authorization
      oauth_callback = params[:oauth_callback] || ''

      consumer = OAuth::Consumer.new(ENV['TWITTER_API_KEY'], ENV['TWITTER_API_SECRET'], {
        site: 'https://api.twitter.com',
        authorize_path: '/oauth/authenticate'
      })
      request_token = consumer.get_request_token(oauth_callback: oauth_callback)
      # puts "\n\n request_token"
      # p request_token
      # puts "\n\n\n"
      # render_success(request_token)
      render_success request_token.params
    end


    swagger_api :access_token do |api|
      summary 'get access token for twitter'
      param :form, :oauth_token, :string, :required
      param :form, :oauth_token_secret, :string, :required
      param :form, :oauth_verifier, :string, :required
    end
    def access_token
      oauth_token = params[:oauth_token] || ''
      oauth_token_secret = params[:oauth_token_secret] || ''
      oauth_verifier = params[:oauth_verifier] || ''

      token_hash = {
        oauth_token: oauth_token,
        oauth_token_secret: oauth_token_secret,
        oauth_callback_confirmed: "true"
      }
      consumer = OAuth::Consumer.new(ENV['TWITTER_API_KEY'], ENV['TWITTER_API_SECRET'], {
        site: 'https://api.twitter.com',
        authorize_path: '/oauth/authenticate'
      })
      request_token  = OAuth::RequestToken.from_hash(consumer, token_hash)
      # puts "\n\n request_token"
      # p request_token
      # puts "\n\n\n"

      access_token = request_token.get_access_token(oauth_verifier: oauth_verifier)
      # puts "\n\n access_token"
      # p access_token
      # puts "\n\n\n"
      # render_success access_token
      render_success access_token.params
    end


    swagger_api :user_info do |api|
      summary 'get user info'
      param :form, :token, :string, :required
      param :form, :secret, :string, :required
      param :form, :user_id, :string, :required
    end
    def user_info
      render_success true
    end
  end
end