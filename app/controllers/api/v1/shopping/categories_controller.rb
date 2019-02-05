module Api::V1::Shopping
  class CategoriesController < ApiController
    swagger_controller :categories, 'Categories'

    skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_api :index do |api|
      summary 'list categories'
    end
    def index
      categories = ShopCategory.all
      render json: categories
    end
  end
end
