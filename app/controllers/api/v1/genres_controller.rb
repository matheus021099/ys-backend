module Api::V1
  class GenresController < ApiController
    skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :genres, 'Genres'

    swagger_api :index do |api|
      summary 'list genres'
    end
    def index
      genres = Genre.where.not(ancestry: nil).order(:name)
      # render json: genres
      render_success genres
    end
  end
end
