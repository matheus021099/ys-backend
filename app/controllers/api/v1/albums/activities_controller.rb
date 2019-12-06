module Api::V1
  class Albums::ActivitiesController < ApiController
    # skip_before_action :authenticate_token!
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    before_action :set_album

    swagger_controller :activities, 'albums/{id}/activities'

    swagger_api :index do |api|
      summary 'list activities'
      param :path, :album_id, :string, :required
      param :query, :action_type, :string, :required, 'repost, download, play'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      action_type = params[:action_type] || 'repost'

      join_query = Activity.for_album(@album.id)
        .where.not(sender_id: @album.user_id)
        .where(action_type: action_type)
        .select('DISTINCT ON (activities.sender_id) activities.id, activities.sender_id, activities.created_at')
        .order(sender_id: :asc, created_at: :desc).to_sql

      activities = Activity.select('t1.*').from('activities t1').order('t1.created_at DESC')
        .joins("INNER JOIN (#{join_query}) t2 ON t1.id = t2.id")
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end


    swagger_api :stats do |api|
      summary 'album stats'
      param :path, :album_id, :string, :required
    end
    def stats
      reposts_size = Activity.for_album(@album.id)
        .where.not(sender_id: @album.user_id)
        .where(action_type: Activity.action_types[:repost])
        .group(:sender_id).count.size

      downloads_size = Activity.for_album(@album.id)
        .where.not(sender_id: @album.user_id)
        .where(action_type: Activity.action_types[:download])
        .group(:sender_id).count.size

      plays_size = Activity.for_album(@album.id)
        .where.not(sender_id: @album.user_id)
        .where(action_type: Activity.action_types[:play])
        .group(:sender_id).count.size

      hides_size = Activity.for_album(@album.id)
        .where.not(sender_id: @album.user_id)
        .where(action_type: Activity.action_types[:hide])
        .group(:sender_id).count.size

      result = {
        reposts_size: reposts_size,
        downloads_size: downloads_size,
        plays_size: plays_size,
        hides_size: hides_size
      }

      render json: result
    end


    setup_authorization_header(:reposted_by)
    swagger_api :reposted_by do |api|
      summary 'reposted_by'
      param :path, :album_id, :string, :required
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def reposted_by
      activities = Activity.for_album(@album.id)
        .where(action_type: Activity.action_types[:repost])
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end


    setup_authorization_header(:downloaded_by)
    swagger_api :downloaded_by do |api|
      summary 'downloaded_by'
      param :path, :album_id, :string, :required
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def downloaded_by
      activities = Activity.for_album(@album.id)
        .where(action_type: Activity.action_types[:download])
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end


    setup_authorization_header(:played_by)
    swagger_api :played_by do |api|
      summary 'played_by'
      param :path, :album_id, :string, :required
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def played_by
      activities = Activity.for_album(@album.id)
        .where(action_type: Activity.action_types[:play])
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)

      render_success(
        activities: ActiveModelSerializers::SerializableResource.new(
          activities,
          each_serializer: ActivitySerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(activities)
      )
    end

    private
    def set_album
      @album = Album.find_by_slug(params[:album_id]) || Album.find(params[:album_id])
    end
  end
end