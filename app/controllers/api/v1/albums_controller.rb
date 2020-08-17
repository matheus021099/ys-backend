module Api::V1
  class AlbumsController < ApiController
    before_action :set_album, only: [
      :update, :destroy, :release, :my_role,
      :request_repost, :repost, :unrepost, :accept_collaboration, :deny_collaboration,
      :send_label_request, :remove_label, :accept_label_request, :deny_label_request,
      :make_public, :make_private, :make_live_video_only, :recommend, :unrecommend,
      :report, :hide, :download, :play, :rearrange, :add_tracks, :remove_tracks
    ]
    skip_before_action :authenticate_token!, only: [:show, :my_role]
    before_action :authenticate_token, only: [:show, :my_role]

    swagger_controller :albums, 'album'

    setup_authorization_header(:index)
    swagger_api :index do |api|
      summary 'get albums'
      param :query, :statuses, :string, :optional, 'any, published, privated, pending, collaboration'
      param :query, :user_statuses, :string, :optional, 'any, accepted, denied, pending'
      param :query, :user_id, :string, :optional, 'user id'
      param :query, :enabled_sample, :boolean, :optional
    end
    def index
      skip_policy_scope
      statuses = params[:statuses].present? ? params[:statuses].split(',').map(&:strip) : ['any']
      user_statuses = params[:user_statuses].present? ? params[:user_statuses].split(',').map(&:strip) : ['any']
      user_id = params[:user_id] || current_user.id
      enabled_sample = params[:enabled_sample].present? ? ActiveModel::Type::Boolean.new.cast(params[:enabled_sample]) : false

      albums = Album.includes(:tracks).joins(:user_albums)
        .where(
          users_albums: {
            user_id: user_id,
            user_type: [
              UserAlbum.user_types[:creator],
              UserAlbum.user_types[:collaborator],
              UserAlbum.user_types[:label]
            ]
          },
          album_type: Album.album_types[:album]
        )
        .where.not(status: Album.statuses[:deleted])
        .order(created_at: :desc)
      albums = albums.where(users_albums: { status: user_statuses }) unless user_statuses.include?('any')
      albums = albums.where(status: statuses) unless statuses.include?('any')
      albums = albums.where(enabled_sample: true) if enabled_sample

      # render_success albums
      render json: ActiveModel::Serializer::CollectionSerializer.new(
        albums,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_collaborators: true,
        include_collaborators_user: true,
      )
    end


    setup_authorization_header(:search)
    swagger_api :search do |api|
      summary 'search albums'
      param :query, :q, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def search
      skip_policy_scope
      # render_success(Album.search "*", load: false)
      # render_success(Album.search "*")

      q = params[:q] || '*'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i
      orders = {}

      albums = Album.search(
        q,
        fields: [:name, :description, :artist_name],
        where: {id: {not: current_user.id}},
        includes: [:tracks, :album_tracks, :user_albums, :user],
        order: orders,
        limit: per_page,
        offset: (page - 1) * per_page
      )

      render_success(
        albums: ActiveModel::Serializer::CollectionSerializer.new(
          albums,
          serializer: AlbumSerializer,
          scope: OpenStruct.new(current_user: current_user),
        ),
        pagination: pagination(albums)
      )
    end


    swagger_api :show do |api|
      summary 'get an album'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required, 'album id and slug'
    end
    def show
      @album = Album.includes(:user, :tracks, samplings: [:sampling_track, :sample_user, :sample_album, :sample_track]).find_by_slug(params[:id]) ||
        Album.includes(:user, :tracks, samplings: [:sampling_track, :sample_user, :sample_album, :sample_track]).find(params[:id])
      authorize @album
      render json:
        @album,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_meta: true,
        include_user_recent: true,
        include_product: true,
        include_collaborators: true,
        include_collaborators_user: true,
        include_contributors: true,
        include_contributors_user: true,
        include_labels: true,
        include_labels_user: true,
        include_samplings: true
      # render_success(@album)
    end


    setup_authorization_header(:create)
    swagger_api :create do |api|
      summary 'create an album'
      # param_list :form, 'album[album_type]', :integer, :optional, , [:album, :playlist]
      param :form, 'album[name]', :string, :optional
      param :form, 'album[description]', :string, :optional
      param :form, 'album[released_at]', :string, :optional
      param :form, 'album[location]', :string, :optional
      param :form, 'album[is_only_for_live_stream]', :boolean, :optional
      param :form, 'album[is_content_acapella]', :boolean, :optional
      param :form, 'album[is_content_instrumental]', :boolean, :optional
      param :form, 'album[is_content_stems]', :boolean, :optional
      param :form, 'album[is_content_remix]', :boolean, :optional
      param :form, 'album[is_content_dj_mix]', :boolean, :optional
      param :form, 'album[cover]', :File, :optional
      param :form, 'album[track_ids]', :string, :optional
      param :form, 'album[genre_ids]', :string, :optional
      param :form, 'album[product_ids]', :string, :optional
      param :form, 'album[collaborators]', :string, :optional, 'refer update API, e.g. [{user_id: "xxx", user_role: "Artist"}]'
      param :form, 'album[contributors]', :string, :optional, 'refer update API, e.g. [{user_id: "xxx", user_role: "Artist"}]'
      param :form, 'album[enabled_sample]', :boolean, :optional
      param :form, 'album[samplings]', :string, :optional
    end
    def create
      @album = Album.new(user: current_user, status: Album.statuses[:pending])
      authorize @album
      album_attributes = permitted_attributes(@album)
      track_ids = params[:album][:track_ids].present? ? params[:album][:track_ids].split(',') : []
      album_attributes[:album_tracks_attributes] = params[:album][:track_ids].split(',').map.with_index(0) {|x, i| {track_id: x, position: i}} if track_ids.size > 0
      @album.attributes = album_attributes
      if params[:album][:genre_ids].present?
        genre_ids = params[:album][:genre_ids].split(',').compact
        # @album.genre_list = Genre.where(id: genre_ids).pluck(:name)
        @album.genre_list = Genre.where(id: genre_ids).pluck(:id)
      end
      if params[:album][:product_ids].present?
        product_ids = params[:album][:product_ids].split(',').compact
        @album.product_list = ShopProduct.where(id: product_ids).pluck(:id)
      end

      contributors_hash = {}
      contributors = []
      contributor = nil
      if params[:album][:contributors].present?
        begin
          data = JSON.parse(params[:album][:contributors])
          contributors_hash = data.inject({}){|o, c| o[c['user_id']] ||= []; o[c['user_id']] << c; o}
          contributors = User.where(id: contributors_hash.keys)
        rescue => ex
        end
      end

      collaborators_count = 0
      collaborators_hash = {}
      collaborators = []
      collaborator = nil
      if params[:album][:collaborators].present?
        begin
          data = JSON.parse(params[:album][:collaborators])
          collaborators_hash = data.inject({}){|o, c| o[c['user_id']] = c; o}
          collaborators = User.where(id: collaborators_hash.keys)
          collaborators_count = collaborators.size
          @album.collaborators_count = collaborators_count
        rescue => ex
        end
      end

      render_errors(@album, :unprocessable_entity) and return unless @album.save

      # assign original album to the tracks
      Track.where(id: track_ids).update_all(album_id: @album.id)

      ActiveRecord::Base.transaction do
        UserAlbum.create(
          user_id: current_user.id,
          album_id: @album.id,
          user_type: UserAlbum.user_types[:creator],
          user_role: 'Artist',
          status: UserAlbum.statuses[:accepted]
        )

        contributors.each do |contributor|
          contributors_hash[contributor.id].each do |contributor_hash|
            UserAlbum.create(
              user_id: contributor.id,
              album_id: @album.id,
              user_type: UserAlbum.user_types[:contributor],
              user_role: contributor_hash['user_role'],
              status: UserAlbum.statuses[:accepted]
            )
          end
        end

        message_body = "#{current_user.display_name} wants to upload this ablum collaboration"
        collaborators.each do |collaborator|
          UserAlbum.create(
            user_id: collaborator.id,
            album_id: @album.id,
            user_type: UserAlbum.user_types[:collaborator],
            user_role: collaborators_hash[collaborator.id]['user_role'],
            status: UserAlbum.statuses[:pending]
          )

          attachment = Attachment.new(
            attachment_type: Attachment.attachment_types[:collaboration],
            attachable_type: @album.class.name,
            attachable_id: @album.id,
            repost_price: 0,
            payment_customer_id: nil,
            payment_token: nil,
            status: Attachment.statuses[:pending]
          )
          receipt = Util::Message.send(current_user, collaborator, message_body, nil, attachment)
        end

        # user_albums = []
        # user_albums << {
        #   user_id: current_user.id,
        #   album_id: @album.id,
        #   user_type: UserAlbum.user_types[:creator],
        #   user_role: 'Artist',
        #   status: UserAlbum.statuses[:accepted]
        # }
        # collaborators.each do |collaborator|
        #   user_albums << {
        #     user_id: collaborator.id,
        #     album_id: @album.id,
        #     user_type: UserAlbum.user_types[:collaborator],
        #     user_role: collaborators_hash[collaborator.id],
        #     status: UserAlbum.statuses[:pending]
        #   }
        # end
        # UserAlbum.bulk_insert values: user_albums
        # Feed.insert(
        #   consumer_id: current_user.id,
        #   publisher_id: current_user.id,
        #   assoc_type: 'Album',
        #   assoc_id: @album.id,
        #   feed_type: Feed.feed_types[:release]
        # )
      end

      @album.release

      unless params[:album][:samplings].blank?
        samplings = []
        sampling = nil

        begin
          data = JSON.parse(params[:album][:samplings])
          Sampling.where(sampling_album_id: @album.id).delete_all
          data.each do |s|
            sampling_track_id = s['sampling_track_id']
            # track = @album.tracks.find{ |t| t.id == sampling_track_id }
            album_track = @album.album_tracks.find{ |at| at.track_id == sampling_track_id }
            if album_track.present?
              s['sampling_album_id'] = @album.id
              s['sampling_user_id'] = @album.user_id
              s['position'] = album_track.position
              samplings << s
            end
          end
        rescue => ex
        end
        # puts "\n\n samplings"
        # p samplings
        # puts "\n\n\n"

        samplings.each do |sampling|
          sample_track = Track.find_by(id: sampling['sample_track_id'])
          next unless sample_track.present?

          Sampling.create(sampling)

          message_body = "[Auto Message] I sampled your song(<b>#{sample_track.name}</b>) on my album"
          attachment = Attachment.new(
            attachment_type: Attachment.attachment_types[:sample_album],
            attachable_type: @album.class.name,
            attachable_id: @album.id,
            repost_price: 0,
            payment_customer_id: nil,
            payment_token: nil,
            status: Attachment.statuses[:accepted]
          )
          receipt = Util::Message.send(current_user, sample_track.user, message_body, nil, attachment)
        end
      end

      render json: @album,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_meta: false
    end


    setup_authorization_header(:update)
    swagger_api :update do |api|
      summary 'update an album'
      param :path, :id, :string, :required
      # param_list :form, 'album[album_type]', :integer, :optional, , [:album, :playlist]
      param :form, 'album[name]', :string, :optional
      param :form, 'album[description]', :string, :optional
      param :form, 'album[released_at]', :string, :optional
      param :form, 'album[location]', :string, :optional
      param :form, 'album[is_only_for_live_stream]', :boolean, :optional
      param :form, 'album[is_content_acapella]', :boolean, :optional
      param :form, 'album[is_content_instrumental]', :boolean, :optional
      param :form, 'album[is_content_stems]', :boolean, :optional
      param :form, 'album[is_content_remix]', :boolean, :optional
      param :form, 'album[is_content_dj_mix]', :boolean, :optional
      param :form, 'album[cover]', :File, :optional
      param :form, 'album[track_ids]', :string, :optional, 'tracks_ids by its present order'
      param :form, 'album[genre_ids]', :string, :optional
      param :form, 'album[product_ids]', :string, :optional
      param :form, 'album[collaborators]', :string, :optional, 'e.g. [{id: "xxx", user_id: "xxx", user_role: "Artist", status: "accepted"}]'
      param :form, 'album[contributors]', :string, :optional, 'e.g. [{id: "xxx", user_id: "xxx", user_role: "Artist"}]'
      param :form, 'album[enabled_sample]', :boolean, :optional
      param :form, 'album[samplings]', :string, :optional
    end
    def update
      authorize @album

      album_attributes = permitted_attributes(@album)
      @album.attributes = album_attributes
      if params[:album][:genre_ids].present?
        genre_ids = params[:album][:genre_ids].split(',').compact
        @album.genre_list = Genre.where(id: genre_ids).pluck(:id)
      end
      if params[:album][:product_ids].present?
        product_ids = params[:album][:product_ids].split(',').compact
        @album.product_list = ShopProduct.where(id: product_ids).pluck(:id)
      end

      contributors_hash = {}
      contributors = []
      contributor = nil
      if params[:album][:contributors].present?
        begin
          data = JSON.parse(params[:album][:contributors])
          contributors_hash = data.inject({}){|o, c| o[c['user_id']] ||= []; o[c['user_id']] << c; o}
          contributors = User.where(id: contributors_hash.keys)
        rescue => ex
        end
      end

      collaborators_count = 0
      collaborators_hash = {}
      collaborators = []
      collaborator = nil
      if params[:album][:collaborators].present?
        begin
          data = JSON.parse(params[:album][:collaborators])
          collaborators_hash = data.inject({}){|o, c| o[c['user_id']] = c; o}
          collaborators = User.where(id: collaborators_hash.keys)
          collaborators_count = collaborators.size
          @album.collaborators_count = collaborators_count
        rescue => ex
        end
      end
      # puts "\n\n collaborators"
      # p data
      # p collaborators_hash
      # p collaborators
      # puts "\n\n\n"

      render_errors(@album, :unprocessable_entity) and return unless @album.save

      if params[:album][:track_ids].present?
        track_ids = params[:album][:track_ids].split(',')
        AlbumTrack.where(album_id: @album.id).delete_all
        track_ids.each_with_index do |track_id, idx|
          AlbumTrack.create(
            album_id: @album.id,
            track_id: track_id,
            position: idx
          )
        end
      end

      if params[:album][:contributors].present?
        ActiveRecord::Base.transaction do
          UserAlbum.where(album_id: @album.id, user_type: UserAlbum.user_types[:contributor]).delete_all
          contributors.each do |contributor|
            contributors_hash[contributor.id].each do |contributor_hash|
              contributor_hash.delete('user')
              contributor_hash.delete('status')
              UserAlbum.create(
                contributor_hash.merge(
                  album_id: @album.id,
                  user_type: UserAlbum.user_types[:contributor],
                  status: UserAlbum.statuses[:accepted]
                )
              )
            end
          end
        end
      end

      if params[:album][:collaborators].present?
        ActiveRecord::Base.transaction do
          UserAlbum.where(album_id: @album.id, user_type: UserAlbum.user_types[:collaborator]).delete_all
          collaborators.each do |collaborator|
            collaborators_hash[collaborator.id].delete('user')
            UserAlbum.create(
              collaborators_hash[collaborator.id].merge(
                album_id: @album.id,
                user_type: UserAlbum.user_types[:collaborator]
              )
            )

            if collaborators_hash[collaborator.id]['id'].blank?
              message_body = "#{current_user.display_name} wants to upload this ablum collaboration"
              attachment = Attachment.new(
                attachment_type: Attachment.attachment_types[:collaboration],
                attachable_type: @album.class.name,
                attachable_id: @album.id,
                repost_price: 0,
                payment_customer_id: nil,
                payment_token: nil,
                status: Attachment.statuses[:pending]
              )
              receipt = Util::Message.send(current_user, collaborator, message_body, nil, attachment)
            end
          end
        end
      end

      @album.release

      unless params[:album][:samplings].blank?
        samplings = []
        sampling = nil

        begin
          data = JSON.parse(params[:album][:samplings])
          Sampling.where(sampling_album_id: @album.id).delete_all
          data.each do |s|
            sampling_track_id = s['sampling_track_id']
            # track = @album.tracks.find{ |t| t.id == sampling_track_id }
            album_track = @album.album_tracks.find{ |at| at.track_id == sampling_track_id }
            if album_track.present?
              s['sampling_album_id'] = @album.id
              s['sampling_user_id'] = @album.user_id
              s['position'] = album_track.position
              samplings << s
            end
          end
        rescue => ex
        end
        # puts "\n\n samplings"
        # p samplings
        # puts "\n\n\n"

        samplings.each do |sampling|
          sample_track = Track.find_by(id: sampling['sample_track_id'])
          next unless sample_track.present?

          Sampling.create(sampling)

          unless sampling['id'].present?
            message_body = "[Auto Message] I sampled your song(<b>#{sample_track.name}</b>) on my album"
            attachment = Attachment.new(
              attachment_type: Attachment.attachment_types[:sample_album],
              attachable_type: @album.class.name,
              attachable_id: @album.id,
              repost_price: 0,
              payment_customer_id: nil,
              payment_token: nil,
              status: Attachment.statuses[:accepted]
            )
            receipt = Util::Message.send(current_user, sample_track.user, message_body, nil, attachment)
          end
        end
      end

      render json: @album,
        serializer: AlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_meta: false
    end


    setup_authorization_header(:destroy)
    swagger_api :destroy do |api|
      summary 'delete an album'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @album
      @album.destroy
      # @album.remove
      render_success(true)
    end


    setup_authorization_header(:release)
    swagger_api :release do |api|
      summary 'release an album'
      param :path, :id, :string, :required
    end
    def release
      authorize @album
      @album.release
      render_success(true)
    end


    setup_authorization_header(:my_role)
    swagger_api :my_role do |api|
      summary 'get current user role on an album'
      param :header, 'Authorization', :string, :optional, 'Authentication token'
      param :path, :id, :string, :required
    end
    def my_role
      skip_authorization
      render json: [] and return unless current_user

      user_albums = UserAlbum.where(
        user_id: current_user.id,
        album_id: @album.id,
        status: UserAlbum.statuses[:accepted]
      )
      render json: ActiveModel::Serializer::CollectionSerializer.new(
        user_albums,
        serializer: UserAlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
      )
    end


    setup_authorization_header(:request_repost)
    swagger_api :request_repost do |api|
      summary 'request to repost an album'
      param :path, :id, :string, :required
    end
    def request_repost
      authorize @album
      @album.request_repost
      render_success(true)
    end


    setup_authorization_header(:repost)
    swagger_api :repost do |api|
      summary 'repost an album'
      param :path, :id, :string, :required
    end
    def repost
      authorize @album rescue render_error "You can't repost your own album", :unprocessable_entity and return
      @album.repost(current_user)
      render_success(true)
    end


    setup_authorization_header(:unrepost)
    swagger_api :unrepost do |api|
      summary 'unrepost an album'
      param :path, :id, :string, :required
    end
    def unrepost
      authorize @album
      @album.unrepost
      render_success(true)
    end


    setup_authorization_header(:accept_collaboration)
    swagger_api :accept_collaboration do |api|
      summary 'accept collaboration on an album'
      param :path, :id, :string, :required
    end
    def accept_collaboration
      authorize @album

      user_album = UserAlbum.find_by(
        user_id: current_user.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:collaborator],
        status: UserAlbum.statuses[:pending]
      )
      user_album.update_attributes(status: UserAlbum.statuses[:accepted]) if user_album.present?

      attachment = Attachment.find_pending(
        sender: @album.user,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:collaboration],
        attachable: @album
      )
      if attachment.present?
        message_body = "#{current_user.display_name} accepted this collaboration"
        attachment.update_attributes(status: Attachment.statuses[:accepted])
        attachment.message.update_attributes(body: message_body)
        attachment.message.mark_as_unread(@album.user)
        # receipt = attachment.message.receipts_for(@album.user).first
        # receipt.update_attributes(is_read: false) if receipt
      end

      render_success true
    end


    setup_authorization_header(:deny_collaboration)
    swagger_api :deny_collaboration do |api|
      summary 'deny collaboration on an album'
      param :path, :id, :string, :required
    end
    def deny_collaboration
      authorize @album

      user_album = UserAlbum.find_by(
        user_id: current_user.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:collaborator],
        status: UserAlbum.statuses[:pending]
      )
      user_album.update_attributes(status: UserAlbum.statuses[:denied]) if user_album.present?

      attachment = Attachment.find_pending(
        sender: @album.user,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:collaboration],
        attachable: @album
      )
      attachment.update_attributes(status: Attachment.statuses[:denied]) if attachment.present?

      render_success true
    end


    setup_authorization_header(:send_label_request)
    swagger_api :send_label_request do |api|
      summary 'send a label request to this album'
      param :path, :id, :string, :required
    end
    def send_label_request
      authorize @album rescue render_error "You don't have a connection to this user", :unprocessable_entity and return

      user_album = UserAlbum.where(
        album_id: @album.id,
        user_type: UserAlbum.user_types[:label]
      ).where.not(status: UserAlbum.statuses[:denied]).first
      render_error 'Someone already claimed this album', :unprocessable_entity and return if user_album.present?

      # user_album = UserAlbum.find_by(
      #   user_id: current_user.id,
      #   album_id: @album.id,
      #   user_type: UserAlbum.user_types[:label]
      # )
      # render_error 'Already sent a label request', :unprocessable_entity and return if user_album.present?

      UserAlbum.create(
        user_id: current_user.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:label],
        status: UserAlbum.statuses[:pending]
      )

      @user = @album.user
      message_body = "#{current_user.display_name} wants to add this ablum to their catalog"
      attachment = Attachment.new(
        attachment_type: Attachment.attachment_types[:label_album],
        attachable_type: @album.class.name,
        attachable_id: @album.id,
        repost_price: 0,
        payment_customer_id: nil,
        payment_token: nil,
        status: Attachment.statuses[:pending]
      )
      receipt = Util::Message.send(current_user, @user, message_body, nil, attachment)

      render_success true
    end


    setup_authorization_header(:remove_label)
    swagger_api :remove_label do |api|
      summary 'remove this album from label list'
      param :path, :id, :string, :required
      param :query, :label_id, :string, :required
    end
    def remove_label
      authorize @album
      label = User.find(params[:label_id])

      user_album = UserAlbum.find_by(
        user_id: label.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:label],
      )

      if user_album.status == UserAlbum.statuses[:pending]
        attachment = Attachment.find_pending(
          sender: current_user,
          receiver: @album.user,
          attachment_type: Attachment.attachment_types[:label_album],
          attachable: @album
        )
        attachment.update_attributes(status: Attachment.statuses[:canceled]) if attachment.present?
      end
      user_album.delete

      render_success true
    end


    setup_authorization_header(:accept_label_request)
    swagger_api :accept_label_request do |api|
      summary 'accept a label album request sent from a label'
      param :path, :id, :string, :required
      param :query, :label_id, :string, :required
    end
    def accept_label_request
      authorize @album
      label = User.find(params[:label_id])

      user_album = UserAlbum.find_by(
        user_id: label.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:label],
        status: UserAlbum.statuses[:pending]
      )
      render_error 'Not found a user_album', :unprocessable_entity and return unless user_album.present?
      user_album.update_attributes(status: UserAlbum.statuses[:accepted])

      attachment = Attachment.find_pending(
        sender: label,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:label_album],
        attachable: @album
      )
      attachment.update_attributes(status: Attachment.statuses[:accepted]) if attachment.present?

      render_success true
    end


    setup_authorization_header(:deny_label_request)
    swagger_api :deny_label_request do |api|
      summary 'deny a label album request sent from a label'
      param :path, :id, :string, :required
      param :query, :label_id, :string, :required
    end
    def deny_label_request
      authorize @album
      label = User.find(params[:label_id])

      user_album = UserAlbum.find_by(
        user_id: label.id,
        album_id: @album.id,
        user_type: UserAlbum.user_types[:label],
        status: UserAlbum.statuses[:pending]
      )
      render_error 'Not found a user_album', :unprocessable_entity and return unless user_album.present?
      user_album.update_attributes(status: UserAlbum.statuses[:denied])

      attachment = Attachment.find_pending(
        sender: label,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:label_album],
        attachable: @album
      )
      attachment.update_attributes(status: Attachment.statuses[:denied]) if attachment.present?

      render_success true
    end


    setup_authorization_header(:make_public)
    swagger_api :make_public do |api|
      summary 'make an album public'
      param :path, :id, :string, :required
    end
    def make_public
      authorize @album
      @album.make_public
      render_success(true)
    end


    setup_authorization_header(:make_private)
    swagger_api :make_private do |api|
      summary 'make an album private'
      param :path, :id, :string, :required
    end
    def make_private
      authorize @album
      @album.make_private
      render_success(true)
    end


    setup_authorization_header(:make_live_video_only)
    swagger_api :make_live_video_only do |api|
      summary 'make an album available only for live video'
      param :path, :id, :string, :required
    end
    def make_live_video_only
      authorize @album
      @album.make_live_video_only
      render_success true
    end


    setup_authorization_header(:recommend)
    swagger_api :recommend do |api|
      summary 'recommend an album'
      param :path, :id, :string, :required
    end
    def recommend
      authorize @album
      @album.recommend(current_user)
      render_success(true)
    end


    setup_authorization_header(:unrecommend)
    swagger_api :unrecommend do |api|
      summary 'unrecommend an album'
      param :path, :id, :string, :required
    end
    def unrecommend
      authorize @album
      @album.unrecommend
      render_success(true)
    end


    setup_authorization_header(:report)
    swagger_api :report do |api|
      summary 'report an album'
      param :path, :id, :string, :required
      param :form, :reason, :string, :optional
      param :form, :description, :string, :optional
    end
    def report
      authorize @album
      ApplicationMailer.report_album(current_user, @album, params[:reason], params[:description]).deliver
      render_success true
    end


    setup_authorization_header(:hide)
    swagger_api :hide do |api|
      summary 'hide an album'
      param :path, :id, :string, :required
    end
    def hide
      authorize @album
      @album.hide(current_user)
      render_success(true)
    end


    setup_authorization_header(:download)
    swagger_api :download do |api|
      summary 'download an album'
      param :path, :id, :string, :required
      param :query, :page_track, :string, :optional
    end
    def download
      authorize @album
      @album.download(current_user, params[:page_track])
      zip_url = @album.generate_zip
      render json: { url: zip_url }
    end


    setup_authorization_header(:play)
    swagger_api :play do |api|
      summary 'play an album'
      param :path, :id, :string, :required
    end
    def play
      authorize @album
      @album.play(current_user)
      render_success(true)
    end


    setup_authorization_header(:rearrange)
    swagger_api :rearrange do |api|
      summary 'rearrange tracks order'
      param :path, :id, :string, :required
      param :form, 'track_ids', :string, :optional
    end
    def rearrange
      authorize @album

      if params[:track_ids].present?
        track_ids = params[:track_ids].split(',').delete_if(&:empty?)
        positions = track_ids.each_with_index.inject({}) {|collaborators_hash, val| collaborators_hash[val[0]] = val[1]; collaborators_hash}
        @album.album_tracks.each do |album_track|
          album_track.position = positions[album_track.track_id]
          album_track.save
        end
      end
      render_success true

      # if params[:track_ids].present?
      #   track_ids = params[:track_ids].split(',')
      #   AlbumTrack.where(album_id: @album.id).delete_all
      #   track_ids.each_with_index do |track_id, idx|
      #     AlbumTrack.create(
      #       album_id: @album.id,
      #       track_id: track_id,
      #       position: idx
      #     )
      #   end
      # end
      # render_success(true)
    end


    setup_authorization_header(:add_tracks)
    swagger_api :add_tracks do |api|
      summary 'add tracks, not implemented, use update'
      param :path, :id, :string, :required
      param :form, 'track_ids', :string, :optional
    end
    def add_tracks
      authorize @album
      render_success(true)
    end


    setup_authorization_header(:remove_tracks)
    swagger_api :remove_tracks do |api|
      summary 'remove tracks, not implemented, use update'
      param :path, :id, :string, :required
      param :form, 'track_ids', :string, :optional
    end
    def remove_tracks
      authorize @album
      render_success(true)
    end


    private
    def set_album
      @album = Album.includes(:user, :tracks).find_by_slug(params[:id]) || Album.includes(:user, :tracks).find(params[:id])
      # @album = current_user.albums.includes(:user).find(params[:id])
    end
  end
end
