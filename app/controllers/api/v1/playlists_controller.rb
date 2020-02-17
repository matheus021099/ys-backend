module Api::V1
  class PlaylistsController < ApiController
    swagger_controller :playlists, 'Playlists'
    before_action :set_album, only: [:update, :destroy, :remove_track]


    swagger_api :index do |api|
      summary 'list playlists'
    end
    def index
      skip_policy_scope
      albums = current_user.playlists.includes(tracks: [:user]).where(status: [Album.statuses[:privated], Album.statuses[:published]])
      render_success Panko::Response.new(
        Panko::ArraySerializer.new(albums, {
          each_serializer: AlbumSerializer1,
          scope: OpenStruct.new(current_user: current_user)
        })
      )
    end


    swagger_api :create do |api|
      summary 'create a playlist'
      param :form, :name, :string, :required
      param :form, :description, :string, :required
      param :form, :cover, :File, :optional
      param :form, :assoc_type, :string, :optional
      param :form, :assoc_id, :string, :optional
    end
    def create
      now = Time.now
      @album = Album.new(
        user_id: current_user.id,
        name: params[:name],
        description: params[:description],
        recommended: false,
        released: false,
        released_at: nil,
        status: Album.statuses[:published],
        album_type: Album.album_types[:playlist],
        created_at: now,
        updated_at: now
      )
      authorize @album

      unless params[:cover].blank?
        @album.cover = params[:cover]
      end

      render_error 'fail to create new playlist', :unprocessable_entity and return unless @album.save

      if params[:assoc_type] == 'Album'
        assoc = Album.includes(:album_tracks)
            .where(id: params[:assoc_id]).first

        # assoc.tracks.each do |track|
        #   @album.tracks << track
        # end

        assoc.album_tracks.each do |album_track|
          AlbumTrack.create(
            album_id: @album.id,
            track_id: album_track.track_id,
            position: album_track.position
          )
        end
      elsif params[:assoc_type] == 'Track'
        track = Track.find(params[:assoc_id])
        AlbumTrack.create(
          album_id: @album.id,
          track_id: track.id,
          position: 0
        )
      end

      UserAlbum.create(
        user_id: current_user.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:creator],
        user_role: 'Artist',
        status: UserAlbum.statuses[:accepted]
      )

      @album.release

      render json: @album,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_meta: false
    end


    swagger_api :update do |api|
      summary 'update a playlist'
      param :path, :id, :string, :required
      param :form, :name, :string, :optional
      param :form, :description, :string, :optional
      param :form, :cover, :File, :optional
      param :form, :assoc_type, :string, :optional
      param :form, :assoc_id, :string, :optional
    end
    def update
      authorize @album

      @album.name = params[:name] unless params[:name].blank?
      @album.description = params[:description] unless params[:description].blank?
      @album.cover = params[:cover] unless params[:cover].blank?

      max_position = @album.album_tracks.maximum('position') + 1

      if params[:assoc_type] == 'Album'
        pos = 0
        assoc = Album.includes(:album_tracks).where(id: params[:assoc_id]).first
        assoc.album_tracks.each do |album_track|
          unless AlbumTrack.exists?(album_id: @album.id, track_id: album_track.track_id)
            AlbumTrack.create(
              album_id: @album.id,
              track_id: album_track.track_id,
              position: max_position + pos
            )
            pos += 1
          end
        end
      elsif params[:assoc_type] == 'Track'
        track = Track.find(params[:assoc_id])
        unless AlbumTrack.exists?(album_id: @album.id, track_id: track.id)
          AlbumTrack.create(
            album_id: @album.id,
            track_id: track.id,
            position: max_position
          )
        end
      end
      @album.save(validate: false)

      render json: @album, serializer: AlbumSerializer, scope: OpenStruct.new(current_user: current_user), include_meta: false
    end


    swagger_api :destroy do |api|
      summary 'remove a playlist'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @album
      @album.destroy
      render_success(true)
    end


    setup_authorization_header(:remove_track)
    swagger_api :remove_track do |api|
      summary 'remove track'
      param :path, :id, :string, :required
      param :form, 'track_id', :string, :optional
    end
    def remove_track
      authorize @album
      AlbumTrack.find_by(
        album_id: @album.id,
        track_id: params[:track_id]
      ).destroy if params[:track_id].present?
      render_success(true)
    end


    private
    def set_album
      @album = Album.find(params[:id])
    end
  end
end