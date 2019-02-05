module Api::V2
  class SearchController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :search, 'search'

    setup_authorization_header(:search_stream)
    swagger_api :search_stream do |api|
      summary 'search stream'
      param :form, :filter, :string, :optional, 'any, uploaded, reposted, downloaded, playlist, merch'
      # param :form, :genre, :string, :optional, 'any, Alt Rock, genre name'
      param :form, :page, :integer, :optional, '1, 2, etc. default is 1'
      param :form, :per_page, :integer, :optional, '12, 24, etc. default is 24'
    end
    def search_stream
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
          include_recent_video: filter === 'video'
        ),
        pagination: pagination(users)
      )
    end

  end
end
