module Api::V1
  class StreamsController < ApiController
    before_action :set_stream, only: [
      :show, :update, :destroy, :notify,
      :start, :stop, :repost,
      :can_view, :pay_view, :view
    ]
    # skip_after_action :verify_authorized
    # skip_after_action :verify_policy_scoped

    swagger_controller :streams, 'stream'

    swagger_api :index do |api|
      summary 'get live streams from who current_user follows'
      param :query, :genre_id, :integer, :options
      param :query, :only_follows, :boolean, :options
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      skip_policy_scope

      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 10).to_i
      only_follows = params[:only_follows].present? ? ActiveModel::Type::Boolean.new.cast(params[:only_follows]) : false
      genre_id = params[:genre_id].to_i rescue 0

      streams = Stream
        .joins("LEFT JOIN follows "\
          "ON streams.user_id = follows.followable_id AND follows.blocked = false AND follows.follower_id = #{current_user.id}"
        )
        .where(
          streams: {
            status: Stream.statuses[:running],
            notified: true
          }
        )
      streams = streams.where("follows.follower_id = ?", current_user.id) if only_follows

      genres = Genre.where(id: streams.pluck(:genre_id)).pluck(:name)

      streams = streams.where("streams.genre_id = ?", genre_id) if genre_id > 0
      streams = streams.order('follows.created_at ASC').page(page).per(per_page)

      render_success(
        streams: ActiveModel::SerializableResource.new(
          streams,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(streams),
        genres: genres
      )
    end


    swagger_api :show do |api|
      summary 'get a stream'
    end
    def show
      authorize @stream

      render json: @stream,
        serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    swagger_api :create do |api|
      summary 'create a stream'
      param :form, 'stream[name]', :string, :required
      param :form, 'stream[description]', :string, :optional
      param :form, 'stream[genre_id]', :string, :required
      param :form, 'stream[view_price]', :integer, :required
      param :form, 'stream[valid_period]', :integer, :required
      param :form, 'stream[cover]', :File, :required
      param :form, 'stream[ml_input_type]', :string, :optional, 'UDP_PUSH, RTP_PUSH, RTMP_PUSH, RTMP_PULL, URL_PULL'
      param :form, 'stream[ml_input_codec]', :string, :optional, 'MPEG2, AVC, HEVC'
      param :form, 'stream[ml_input_resolution]', :string, :optional, 'SD, HD, UHD'
      param :form, 'stream[ml_input_maximum_bitrate]', :string, :optional, 'MAX_10_MBPS, MAX_20_MBPS, MAX_50_MBPS'
    end
    def create
      # skip_authorization
      @stream = current_user.stream
      @stream = Stream.new(user: current_user, status: Stream.statuses[:active]) unless @stream.present?
      authorize @stream

      genre_id = params[:stream][:genre_id]
      view_price = params[:stream][:view_price].to_i rescue 0

      begin
        mux = Services::Mux.new
        res = mux.createStream()
        Rails.logger.info(res)

        playback1_id = res['data']['playback_ids'][0]['id'] rescue ''
        playback2_id = res['data']['playback_ids'][1]['id'] rescue ''
        @stream.assign_attributes(
          name: params[:stream][:name],
          description: params[:stream][:description] || '',
          genre_id: genre_id,
          view_price: view_price,
          cover: params[:stream][:cover],
          ml_channel_id: res['data']['id'],
          ml_input_id: res['data']['stream_key'],
          ml_input_dest_1_url: 'rtmp://live.yousound.com:5222/app',
          ml_input_dest_2_url: 'rtmp://live.yousound.com:433/app',
          mp_channel_1_ep_1_id: playback1_id,
          mp_channel_1_ep_1_url: playback1_id.blank? ? "https://stream.mux.com/#{playback1_id}.m3u8" : '',
          mp_channel_2_ep_1_id: playback2_id,
          mp_channel_2_ep_1_url: playback2_id.blank? ? "https://stream.mux.com/#{playback2_id}.m3u8" : '',
          cf_domain: nil,
          status: Stream.statuses[:active]
        )
        if params[:stream][:assoc_type].present? && params[:stream][:assoc_id].present?
          @stream.assoc_id = params[:stream][:assoc_id]
          @stream.assoc_type = params[:stream][:assoc_type]
        end
        @stream.save!
      rescue => e
        render_error e.message, :unprocessable_entity and return
      end

      render json: @stream,
        serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    swagger_api :update do |api|
      summary 'update a stream'
      param :path, :id, :string, :required, 'stream id'
      param :form, 'stream[guests_ids]', :string, :optional
      param :form, 'stream[viewers_limit]', :integer, :optional
      param :form, 'stream[extend_period]', :integer, :optional
      param :form, 'stream[assoc_type]', :string, :optional, 'Album, ShopProduct'
      param :form, 'stream[assoc_id]', :string, :optional
    end
    def update
      authorize @stream

      if params[:stream][:guests_ids].present?
        guests_ids = params[:stream][:guests_ids].split(',').compact
        @stream.guest_list = User.where(id: guests_ids).pluck(:id)
      end

      # extend_period = params[:stream][:extend_period].to_i rescue 0
      # @stream.valid_period += extend_period if extend_period > 0

      @stream.attributes = permitted_attributes(@stream)
      @stream.save!

      # Rails.logger.info("\n\n\n streams/:id/update: #{params[:stream][:assoc_type].present?}, #{params[:stream][:assoc_id].present?}\n\n\n")
      if params[:stream][:assoc_id].present?
        assoc = @stream.assoc

        result = {}
        case assoc.class.name
          when 'Album'
            result = AlbumSerializer.new(assoc).as_json
          when 'ShopProduct'
            result = ShopProductSerializer.new(assoc).as_json
          when 'User'
            result = UserSerializer.new(assoc).as_json
        end
        ActionCable.server.broadcast("stream_#{@stream.id}", {assoc_type: @stream.assoc_type, assoc: result})

        # send push notification to watchers
        data = {
          id: @stream.id,
          user_id: @stream.user_id,
          assoc_type: @stream.assoc_type,
          assoc: Util::Serializer.polymophic_serializer(assoc)
        }

        user_ids = Activity.where(
          action_type: Activity.action_types[:view_stream],
          page_track: "#{@stream.class.name}: #{@stream.id}"
        ).group(:sender_id).pluck(:sender_id)

        user_ids << @stream.user_id
        user_ids.uniq!

        PushNotificationWorker.perform_async(
          Device.where(user_id: user_ids, enabled: true).pluck(:token),
          FCMService::push_notification_types[:video_attachment_changed],
          "[#{current_user.display_name}] has updated the video attachment",
          data
        )
      end

      render_success StreamSerializer.new(@stream, scope: OpenStruct.new(current_user: current_user)).as_json
      # render json: @stream,
      #   serializer: StreamSerializer,
      #   scope: OpenStruct.new(current_user: current_user)
    end


    swagger_api :destroy do |api|
      summary 'destroy a stream'
      param :path, :id, :string, :required, 'stream id'
    end
    def destroy
      authorize @stream

      result = @stream.remove
      render_error result, :unprocessable_entity and return unless result === true

      # render json: @stream,
      #   serializer: StreamSerializer,
      #   scope: OpenStruct.new(current_user: current_user)
      current_user.reload
      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end


    setup_authorization_header(:notify)
    swagger_api :notify do |api|
      summary 'notify followers that live stream is broadcasting'
      param :path, :id, :string, :required, 'stream id'
    end
    def notify
      authorize @stream

      user_ids = current_user.followers.pluck(:id)
      message_body = "#{current_user.display_name} broadcast a live stream"
      data = @stream.as_json(
        only: [ :id, :user_id, :name, :cover ],
        include: {
          user: {
            only: [ :id, :slug, :name, :username, :avatar ]
          }
        }
      )
      data[:assoc] = Util::Serializer.polymophic_serializer(@stream.assoc)

      PushNotificationWorker.perform_async(
        Device.where(user_id: user_ids, enabled: true).pluck(:token),
        FCMService::push_notification_types[:video_started],
        message_body,
        data
      )

      render_success true
    end


    setup_authorization_header(:start)
    swagger_api :start do |api|
      summary 'start a stream'
      param :path, :id, :string, :required, 'stream id'
    end
    def start
      authorize @stream

      begin
        now = Time.now
        medialive = Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
        medialive.start_channel({
          channel_id: @stream.ml_channel_id
        })
        @stream.update_attributes(
          started_at: now,
          checkpoint_at: now,
          status: Stream.statuses[:running]
        )
      rescue => e
        render_error e.message, :unprocessable_entity and return
      end

      render json: @stream,
        serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    setup_authorization_header(:stop)
    swagger_api :stop do |api|
      summary 'stop a stream'
      param :path, :id, :string, :required, 'stream id'
    end
    def stop
      authorize @stream

      begin
        medialive = Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
        medialive.stop_channel({
          channel_id: @stream.ml_channel_id
        })
        @stream.update_attributes(
          stopped_at: Time.now,
          status: Stream.statuses[:active]
        )
      rescue => e
        render_error e.message, :unprocessable_entity and return
      end

      render json: @stream,
        serializer: StreamSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    setup_authorization_header(:repost)
    swagger_api :repost do |api|
      summary 'repost a stream'
      param :path, :id, :string, :required
    end
    def repost
      authorize @stream rescue render_error "You can't repost your own live video", :unprocessable_entity and return
      @stream.repost(current_user)
      render_success(true)
    end


    setup_authorization_header(:can_view)
    swagger_api :can_view do |api|
      summary 'can view a stream'
      param :path, :id, :string, :required
    end
    def can_view
      skip_authorization
      result = @stream.can_view(current_user)
      render_success result
    end


    setup_authorization_header(:pay_view)
    swagger_api :pay_view do |api|
      summary 'pay to view a stream'
      param :path, :id, :string, :required
      param :form, :amount, :integer, :required, 'amount in cent'
      param :form, :payment_token, :string, :optional
    end
    def pay_view
      skip_authorization
      payment = Payment.pay_view_stream(
        sender: current_user,
        stream: @stream,
        payment_token: params[:payment_token]
      )
      render_error payment, :unprocessable_entity and return unless payment.kind_of? Payment
      render_success true
    end


    setup_authorization_header(:view)
    swagger_api :view do |api|
      summary 'view a stream'
      param :path, :id, :string, :required
    end
    def view
      authorize @stream rescue render_success(false) and return
      @stream.view(current_user)
      render_success true
    end

    private
    def set_stream
      @stream = Stream.find(params[:id])
    end
  end
end
