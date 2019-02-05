module Api::V1
  class TracksController < ApiController
    swagger_controller :tracks, 'Track Management'
    before_action :set_track, only: [:show, :update, :destroy, :download, :play]

    swagger_api :create do |api|
      summary 'Create a track'
      param :form, 'track[name]', :string, :required
      param :form, 'track[description]', :string, :required
      param :form, 'track[audio]', :File, :optional
      # param :form, 'album_id', :string, :optional, 'album id or slug'
    end
    def create
      track = Track.new(user: current_user)
      authorize track
      track.attributes = permitted_attributes(track)

      unless params[:track][:audio].instance_of? ActionDispatch::Http::UploadedFile
        render_error "Pass the audio", :unprocessable_entity and return
      end

      # clip_path = Util::Audio.clip params[:track][:audio].path
      # track.clip = File.open(clip_path)

      # res = Util::Audio.check_global_fingerprint(clip_path)
      # if !res.blank? && res["status"]["code"] == 0
      #   track_title = res["metadata"]["music"][0]["title"]
      #   artist_name = res["metadata"]["music"][0]["artists"][0]["name"]
      #   if artist_name.downcase != current_user.name.downcase
      #     render json: {
      #       code: 1,
      #       track_title: track_title,
      #       artist_name: artist_name,
      #       errors: ['unauthorized']
      #     }, status: :unprocessable_entity and return
      #   end
      # end

      # res = Util::Audio.check_local_fingerprint(clip_path)
      # if !res.blank? && res["status"]["code"] == 0
      #   track_title = res["metadata"]["custom_files"][0]["name"]
      #   artist_name = res["metadata"]["custom_files"][0]["artist"]
      #   render json: {
      #     code: 2,
      #     track_title: track_title,
      #     artist_name: artist_name,
      #     errors: ['duplicate']
      #   }, status: :unprocessable_entity and return
      # end

      if track.save
        # res = Util::Audio.add_to_acr(
        #   file_path: params[:track][:audio].path,
        #   track_id: track.id,
        #   track_name: track.name,
        #   artist_name: current_user.name.blank? ? current_user.display_name : current_user.name
        # )
        # acr_id = res["acr_id"] rescue nil
        # track.update_attributes(acr_id: acr_id) unless acr_id.blank?

        render_success track
      else
        render_errors track, :unprocessable_entity
      end
      # unless params[:album_id].blank?
      #   album = Album.find_by(slug: params[:album_id]) || Album.find_by(id: params[:album_id])
      #   if album.present?
      #     AlbumTrack.create(
      #       album_id: album.id,
      #       track_id: track.id,
      #       position: album.tracks.size
      #     )
      #   end
      # end
      # render_success track
    end


    swagger_api :update do |api|
      summary 'Update a track'
      param :path, :id, :string, :required
      param :form, 'track[name]', :string, :required
    end
    def update
      authorize @track
      @track.attributes = permitted_attributes(@track)
      @track.save(validate: false)

      Util::Audio.update_in_acr(
        acr_id: @track.acr_id,
        track_name: @track.name,
        artist_name: current_user.name.blank? ? current_user.display_name : current_user.name
      ) unless @track.acr_id.blank?

      render_success @track
    end


    swagger_api :destroy do |api|
      summary 'Delete a track'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @track, :destroy?
      # @track.status = Track.statuses[:inacitve]
      # @track.save
      @track.remove

      render_success(true)
    end


    setup_authorization_header(:download)
    swagger_api :download do |api|
      summary 'download a track'
      param :path, :id, :string, :required
      param :query, :page_track, :string, :optional
    end
    def download
      authorize @track
      @track.download(current_user, params[:page_track])
      render_success true
    end


    setup_authorization_header(:play)
    swagger_api :play do |api|
      summary 'play a track'
      param :path, :id, :string, :required
    end
    def play
      authorize @track
      @track.play(current_user)
      render_success true
    end


    private

    def set_track
      @track = Track.find_by_slug(params[:id]) || Track.find(params[:id])
    end
  end
end