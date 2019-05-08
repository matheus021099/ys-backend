class ApplicationController < ActionController::API
  include ActionController::Serialization
  include Pundit

  attr_reader :current_user, :current_cart

  before_action :authenticate_token!

  after_action :verify_authorized, except: [:index, :search]
  after_action :verify_policy_scoped, only: [:index, :search]

  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity_response
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_response
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # serialization_scope :view_context

  protected

  def authenticate_token
    payload = JsonWebToken.decode(auth_token)
    @current_user = User.find(payload['id'])
    AuthenticatorConcern.current_user = @current_user
  rescue => ex
    # puts "\n\n #{ex.message} \n\n\n"
  end

  def authenticate_token!
    payload = JsonWebToken.decode(auth_token)
    @current_user = User.find(payload['id'])
    @current_cart = current_user.current_cart
    AuthenticatorConcern.current_user = @current_user
  rescue JWT::ExpiredSignature
    render_error('Auth token has expired', :unauthorized)
  rescue JWT::DecodeError
    render_error('Invalid auth token', :unauthorized)
  end

  def auth_token
    @auth_token ||= request.headers.fetch('Authorization', '').split(' ').last
  end

  def render_error(message, status)
    render json: { errors: [message] }, status: status
  end

  def render_errors(resource, status)
    render json: resource, status: status, adapter: :json_api,
           serializer: ActiveModel::Serializer::ErrorSerializer
  end

  def render_success(response)
    render json: response
  end

  def pagination(collection)
    {
      per_page: collection.limit_value,
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      # count: collection.count,
      count: collection.length,
      total_count: collection.total_count,
    }
  end

  private
  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    render_error("not allowed in #{policy_name}.#{exception.query}", :unprocessable_entity)
  end

  def render_unprocessable_entity_response(exception)
    render_errors(exception.record, :unprocessable_entity)
  end

  def render_not_found_response(exception)
    render_error(exception.message, :not_found)
  end
end