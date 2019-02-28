module Api::V2
  class GenresController < ApiController
    skip_before_action :authenticate_token!, only: [:index]
    skip_after_action :verify_policy_scoped
    before_action :set_genre, only: [:update, :destroy]

    swagger_controller :genres, 'Genres'

    swagger_api :index do |api|
      summary 'list genres'
    end
    def index
      skip_authorization

      # genres = Genre.arrange_serializable
      # render_success genres

      # genres = Genre.arrange_serializable do |parent, children|
      #   GenreSerializer.new(parent)
      # end

      genre_users_sql = <<-SQL
        SELECT t.genre_id, COUNT (1)
        FROM (
          SELECT DISTINCT ON (1, 2) CAST(tags.name as int) AS genre_id, a.user_id
          FROM taggings tg
          JOIN albums a ON tg.taggable_id = a.id
          JOIN tags ON tg.tag_id = tags.id
          WHERE tg.taggable_type = 'Album' AND tg.context = 'genres'
        ) t
        GROUP BY t.genre_id
      SQL
      genre_users = Genre.connection.execute(genre_users_sql).to_a.inject({}){|obj, r| obj[r['genre_id']] = r['count'].to_i; obj}

      genres = Genre.roots.order(:sequence)
      render json: genres, scope: OpenStruct.new(genre_users: genre_users), include_children: true
    end


    setup_authorization_header(:create)
    swagger_api :create do |api|
      summary 'create a genre'
      param :form, 'genre[name]', :string, :required
      param :form, 'genre[ancestry]', :string, :optional, 'parent genre id'
    end
    def create
      @genre = Genre.new
      authorize @genre
      @genre.attributes = permitted_attributes(@genre)

      if params[:genre][:ancestry].present?
        ancestry = Genre.where(id: params[:genre][:ancestry], ancestry: nil).first
        render_error 'ancestry is not valid', :unprocessable_entity and return unless ancestry.present?
        @genre.ancestry = ancestry.id
      end

      if @genre.save
        render_success true
      else
        render_errors @genre, :unprocessable_entity
      end
    end


    setup_authorization_header(:update)
    swagger_api :update do |api|
      summary 'update a genre'
      param :path, :id, :string, :required
      param :form, 'genre[name]', :string, :required
    end
    def update
      authorize @genre
      @genre.attributes = permitted_attributes(@genre)
      if @genre.save
        render_success true
      else
        render_errors @genre, :unprocessable_entity
      end
    end


    setup_authorization_header(:destroy)
    swagger_api :destroy do |api|
      summary 'destroy a genre'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @genre
      @genre.remove
      render_success true
    end


    private
    def set_genre
      @genre = Genre.find(params[:id])
    end

  end
end
