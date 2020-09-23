module Api::V1
  class PlayersController < ApiController
    swagger_controller :player, 'Player'

    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped


    swagger_api :track_by_id do |api|
      summary 'get track by id'
      param :form, :track_id, :string, :optional
      param :form, :album_id, :string, :optional
    end
    def track_by_id
      set_track
      set_album

      states = {
        # user_id: @album.user.id,
        # category: 'explore',
        # filter: '',
        # genre: '',
        # url: '#',
        # album_offset: 0,
        # track_offset: 0
      }
      render_success(serializer(states))
    end


    swagger_api :track_by_offset do |api|
      summary 'get track by offset'
      param :form, :states, :string, :optional
    end
    def track_by_offset
      states = ActiveSupport::JSON.decode(params[:states]) || {}
      category = states[:category] || 'explore'
      album_offset = states[:album_offset] || 0
      track_offset = states[:track_offset] || 0
      genre = states[:genre] || 'any'

      if track_offset < 0
        album_offset -= 1
        track_offset = 0
      end

      @album = case category
        when 'explore'
         filter = states[:filter] || 'popular'
         q = states[:q]
         User.explore_query(q, filter, genre, { offset: album_offset, limit: 1 }, state[:user_id] || 0)
        when 'feed'
         filter = states[:filter] || 'uploaded'
         feed = User.find(states[:user_id]).feed_query(filter, genre).offset(album_offset).limit(1).first
         feed.nil? ? nil : feed_item.assoc
        when 'song'
         filter = states[:filter] || 'new'
         User.find(states[:user_id]).album_query(filter, genre).offset(album_offset).limit(1).first
        when 'playlist'
         filter = states[:filter] || 'any'
         User.find(states[:user_id]).playlist_query(filter, genre).offset(album_offset).limit(1).first
        when 'downloaded'
         filter = states[:filter] || 'new'
         User.find(states[:user_id]).download_query(filter, genre).offset(album_offset).limit(1).first
      end
      render_error('album not found', 200) and return if @album.nil?

      if @album.tracks.length <= track_offset
        album_offset += 1
        track_offset = 0
      end

      @album = case category
        when 'explore'
         filter = states[:filter] || 'popular'
         q = states[:q]
         User.explore_query(q, filter, genre, { offset: album_offset, limit: 1 }, state[:user_id] || 0)
        when 'feed'
         filter = states[:filter] || 'uploaded'
         feed_item = User.find(states[:user_id]).feed_query(filter, genre).offset(album_offset).limit(1).first
         feed_item.nil? ? nil : feed_item.assoc
        when 'song'
         filter = states[:filter] || 'new'
         User.find(states[:user_id]).album_query(filter, genre).offset(album_offset).limit(1).first
        when 'playlist'
         filter = states[:filter] || 'any'
         User.find(states[:user_id]).playlist_query(filter, genre).offset(album_offset).limit(1).first
        when 'downloaded'
         filter = states[:filter] || 'new'
         User.find(states[:user_id]).download_query(filter, genre).offset(album_offset).limit(1).first
      end
      render_error('album not found', 200) and return if @album.nil?

      # states = {
      #   category: 'new',
      #   album_offset: 0,
      #   track_offset: 0
      # }
      @track = @album.tracks.offset(track_offset).limit(1).first
      states[:album_offset] = album_offset
      states[:track_offset] = track_offset

      render_success(serializer(states))
    end

    private
      def set_album
        @album = Album.find_by_slug(params[:album_id]) || Album.find(params[:album_id])
        render_error('album not_found', 200) and return unless @album
      end

      def set_track
        @track = Track.find_by_id(params[:track_id])
        render_error('album not_found', 200) and return unless @track
      end

      def serializer(states)
        return {
          track_id: @track.id,
          track_name: @track.name,
          audio_url: @track.audio_url,
          # track_url: track_path(username: @album.user.username, track_id: @album.slug),

          album: {
            album_id: @album.id,
            album_name: @album.name,
            description: @album.description,
            cover_url: @album.cover_url,
            # album_url: Rails.application.routes.url_helpers.track_path(username: @album.listener.username, track_id: @album.slug),

            artist_name: @album.user.name,
            # artist_url: Rails.application.routes.url_helpers.profile_path(username: @album.listener.username),

            tracks_count: @album.tracks.length
          },

          states: states
        }
      end
  end
end
