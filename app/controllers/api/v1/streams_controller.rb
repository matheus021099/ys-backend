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

      in_sec_group_id = ENV['AWS_MEDIALIVE_INPUT_SECURITY_GROUP_ID'] || '7767738'
      ml_input_type = params[:stream][:ml_input_type] || 'RTMP_PUSH'
      ml_input_codec = params[:stream][:ml_input_codec] || 'HEVC'
      ml_input_resolution = params[:stream][:ml_input_resolution] || 'HD'
      ml_input_maximum_bitrate = params[:stream][:ml_input_type] || 'MAX_50_MBPS'
      uniq_id = current_user.slug
      @stream.valid_period = params[:stream][:valid_period].to_i

      begin
        medialive = Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
        mediapackage = Aws::MediaPackage::Client.new(region: ENV['AWS_REGION'])
        ssm = Aws::SSM::Client.new(region: ENV['AWS_REGION'])

        # in_sec_group = medialive.describe_input_security_group({
        #   input_security_group_id: in_sec_group_id
        # })
        # in_sec_group = medialive.create_input_security_group({
        #   whitelist_rules: [
        #     { cidr: '0.0.0.0/0' },
        #   ],
        # })

        ml_in_id = nil
        if @stream.ml_input_id.present?
          resp = medialive.describe_input({
            input_id: @stream.ml_input_id
          }) rescue nil

          if resp && resp.state == 'DETACHED'
            ml_in_id = @stream.ml_input_id
          end
        end

        if ml_in_id.blank?
          req = {
            destinations: [
              { stream_name: "#{uniq_id}_ml_in_dest_a/#{uniq_id}_ml_in_dest_a_inst" },
              { stream_name: "#{uniq_id}_ml_in_dest_b/#{uniq_id}_ml_in_dest_a_inst" },
            ],
            input_security_groups: [in_sec_group_id],
            name: "#{uniq_id}_ml_in",
            type: ml_input_type
          }
          ml_in = medialive.create_input(req).input
          @stream.ml_input_id = ml_in.id
          @stream.ml_input_dest_1_url = ml_in.destinations[0].url
          @stream.ml_input_dest_2_url = ml_in.destinations[1].url
          ml_in_id = @stream.ml_input_id
        end

        mp_channel_1 = mediapackage.create_channel({ id: "#{uniq_id}_mp_channel_1" })
        mp_channel_1_url = mp_channel_1.hls_ingest.ingest_endpoints[0].url
        mp_channel_1_username = mp_channel_1.hls_ingest.ingest_endpoints[0].username
        mp_channel_1_password = mp_channel_1.hls_ingest.ingest_endpoints[0].password

        mp_channel_2 = mediapackage.create_channel({ id: "#{uniq_id}_mp_channel_2" })
        mp_channel_2_url = mp_channel_2.hls_ingest.ingest_endpoints[0].url
        mp_channel_2_username = mp_channel_2.hls_ingest.ingest_endpoints[0].username
        mp_channel_2_password = mp_channel_2.hls_ingest.ingest_endpoints[0].password

        req = {
          # id: "#{uniq_id}_mp_channel_1_ep_1",
          # channel_id: mp_channel_1.id,
          hls_package: {
            segment_duration_seconds: 6,
            stream_selection: {
                max_video_bits_per_second: 2147483647,
                min_video_bits_per_second: 0,
                stream_order: 'ORIGINAL'
            },
            use_audio_rendition_group: false
          },
          # startover_window_seconds: 300,
          # time_delay_seconds: 1,
        }
        mp_channel_1_ep_1 = mediapackage.create_origin_endpoint(req.merge(
          id: "#{uniq_id}_mp_channel_1_ep_1",
          channel_id: mp_channel_1.id))
        mp_channel_1_ep_1_url = mp_channel_1_ep_1.url

        mp_channel_2_ep_1 = mediapackage.create_origin_endpoint(req.merge(
          id: "#{uniq_id}_mp_channel_2_ep_1",
          channel_id: mp_channel_2.id))
        mp_channel_2_ep_1_url = mp_channel_2_ep_1.url

        ssm.put_parameter({
          name: "/medialive/#{mp_channel_1.id}_user",
          type: "SecureString",
          value: mp_channel_1_password,
          overwrite: true
        })

        ssm.put_parameter({
          name: "/medialive/#{mp_channel_2.id}_user",
          type: "SecureString",
          value: mp_channel_2_password,
          overwrite: true
        })

        req = {
          name: "#{uniq_id}_ml_channel",
          destinations: [
            {
              # id: "#{uniq_id}-destination-1",
              id: "destination1",
              settings: [
                {
                  url: mp_channel_1_url,
                  username: mp_channel_1_username,
                  password_param: "/medialive/#{mp_channel_1.id}_user"
                },
                {
                  url: mp_channel_2_url,
                  username: mp_channel_2_username,
                  password_param: "/medialive/#{mp_channel_2.id}_user"
                }
              ]
            }
          ],
          encoder_settings: {
            audio_descriptions: [
              {
                audio_selector_name: "Default",
                codec_settings: {
                  aac_settings: {
                    input_type: "NORMAL",
                    bitrate: 192000,
                    coding_mode: "CODING_MODE_2_0",
                    raw_format: "NONE",
                    spec: "MPEG4",
                    profile: "LC",
                    rate_control_mode: "CBR",
                    sample_rate: 48000
                  }
                },
                audio_type_control: "FOLLOW_INPUT",
                language_code_control: "FOLLOW_INPUT",
                name: "audio_1"
              },
              {
                audio_selector_name: "Default",
                codec_settings: {
                  aac_settings: {
                    input_type: "NORMAL",
                    bitrate: 192000,
                    coding_mode: "CODING_MODE_2_0",
                    raw_format: "NONE",
                    spec: "MPEG4",
                    profile: "LC",
                    rate_control_mode: "CBR",
                    sample_rate: 48000
                  }
                },
                audio_type_control: "FOLLOW_INPUT",
                language_code_control: "FOLLOW_INPUT",
                name: "audio_2"
              },
              {
                audio_selector_name: "Default",
                codec_settings: {
                  aac_settings: {
                    input_type: "NORMAL",
                    bitrate: 128000,
                    coding_mode: "CODING_MODE_2_0",
                    raw_format: "NONE",
                    spec: "MPEG4",
                    profile: "LC",
                    rate_control_mode: "CBR",
                    sample_rate: 48000
                  }
                },
                audio_type_control: "FOLLOW_INPUT",
                language_code_control: "FOLLOW_INPUT",
                name: "audio_3"
              },
              {
                audio_selector_name: "Default",
                codec_settings: {
                  aac_settings: {
                    input_type: "NORMAL",
                    bitrate: 128000,
                    coding_mode: "CODING_MODE_2_0",
                    raw_format: "NONE",
                    spec: "MPEG4",
                    profile: "LC",
                    rate_control_mode: "CBR",
                    sample_rate: 48000
                  }
                },
                audio_type_control: "FOLLOW_INPUT",
                language_code_control: "FOLLOW_INPUT",
                name: "audio_4"
              }
            ],
            output_groups: [
              {
                output_group_settings: {
                  hls_group_settings: {
                    ad_markers: [],
                    caption_language_setting: "OMIT",
                    caption_language_mappings: [],
                    hls_cdn_settings: {
                      hls_webdav_settings: {
                        num_retries: 10,
                        connection_retry_interval: 1,
                        restart_delay: 15,
                        filecache_duration: 300,
                        http_transfer_mode: "NON_CHUNKED"
                      }
                    },
                    input_loss_action: "EMIT_OUTPUT",
                    manifest_compression: "NONE",
                    destination: {
                      # destination_ref_id: "#{uniq_id}-destination-1"
                      destination_ref_id: "destination1"
                    },
                    iv_in_manifest: "INCLUDE",
                    iv_source: "FOLLOWS_SEGMENT_NUMBER",
                    client_cache: "ENABLED",
                    ts_file_mode: "SEGMENTED_FILES",
                    manifest_duration_format: "INTEGER",
                    segmentation_mode: "USE_SEGMENT_DURATION",
                    output_selection: "MANIFESTS_AND_SEGMENTS",
                    stream_inf_resolution: "INCLUDE",
                    index_n_segments: 10,
                    program_date_time: "EXCLUDE",
                    program_date_time_period: 600,
                    keep_segments: 21,
                    segment_length: 6,
                    timed_metadata_id_3_frame: "PRIV",
                    timed_metadata_id_3_period: 10,
                    codec_specification: "RFC_4281",
                    directory_structure: "SINGLE_DIRECTORY",
                    segments_per_subdirectory: 10000,
                    mode: "LIVE"
                  }
                },
                name: "HD",
                outputs: [
                  {
                    output_settings: {
                      hls_output_settings: {
                        name_modifier: "_1080p30",
                        hls_settings: {
                          standard_hls_settings: {
                            m3u_8_settings: {
                              audio_frames_per_pes: 4,
                              audio_pids: "492-498",
                              ecm_pid: "8182",
                              pcr_control: "PCR_EVERY_PES_PACKET",
                              pmt_pid: "480",
                              program_num: 1,
                              scte_35_pid: "500",
                              scte_35_behavior: "NO_PASSTHROUGH",
                              # timed_metadata_pid: "502",
                              timed_metadata_behavior: "NO_PASSTHROUGH",
                              video_pid: "481"
                            },
                            audio_rendition_sets: "PROGRAM_AUDIO"
                          }
                        }
                      }
                    },
                    video_description_name: "video_1080p30",
                    audio_description_names: [
                      "audio_1"
                    ],
                    caption_description_names: []
                  },
                  {
                    output_settings: {
                      hls_output_settings: {
                        name_modifier: "_720p30",
                        hls_settings: {
                          standard_hls_settings: {
                            m3u_8_settings: {
                              audio_frames_per_pes: 4,
                              audio_pids: "492-498",
                              ecm_pid: "8182",
                              pcr_control: "PCR_EVERY_PES_PACKET",
                              pmt_pid: "480",
                              program_num: 1,
                              scte_35_pid: "500",
                              scte_35_behavior: "NO_PASSTHROUGH",
                              # timed_metadata_pid: "502",
                              timed_metadata_behavior: "NO_PASSTHROUGH",
                              video_pid: "481"
                            },
                            audio_rendition_sets: "PROGRAM_AUDIO"
                          }
                        }
                      }
                    },
                    video_description_name: "video_720p30",
                    audio_description_names: [
                      "audio_2"
                    ],
                    caption_description_names: []
                  },
                  {
                    output_settings: {
                      hls_output_settings: {
                        name_modifier: "_480p30",
                        hls_settings: {
                          standard_hls_settings: {
                            m3u_8_settings: {
                              audio_frames_per_pes: 4,
                              audio_pids: "492-498",
                              ecm_pid: "8182",
                              pcr_control: "PCR_EVERY_PES_PACKET",
                              pmt_pid: "480",
                              program_num: 1,
                              scte_35_pid: "500",
                              scte_35_behavior: "NO_PASSTHROUGH",
                              # timed_metadata_pid: "502",
                              timed_metadata_behavior: "NO_PASSTHROUGH",
                              video_pid: "481"
                            },
                            audio_rendition_sets: "PROGRAM_AUDIO"
                          }
                        }
                      }
                    },
                    video_description_name: "video_480p30",
                    audio_description_names: [
                      "audio_3"
                    ],
                    caption_description_names: []
                  },
                  {
                    output_settings: {
                      hls_output_settings: {
                        name_modifier: "_240p30",
                        hls_settings: {
                          standard_hls_settings: {
                            m3u_8_settings: {
                              audio_frames_per_pes: 4,
                              audio_pids: "492-498",
                              ecm_pid: "8182",
                              pcr_control: "PCR_EVERY_PES_PACKET",
                              pmt_pid: "480",
                              program_num: 1,
                              scte_35_pid: "500",
                              scte_35_behavior: "NO_PASSTHROUGH",
                              # timed_metadata_pid: "502",
                              timed_metadata_behavior: "NO_PASSTHROUGH",
                              video_pid: "481"
                            },
                            audio_rendition_sets: "PROGRAM_AUDIO"
                          }
                        }
                      }
                    },
                    video_description_name: "video_240p30",
                    audio_description_names: [
                      "audio_4"
                    ],
                    caption_description_names: []
                  }
                ]
              }
            ],
            timecode_config: {
              source: "EMBEDDED"
            },
            video_descriptions: [
              {
                codec_settings: {
                  h264_settings: {
                    afd_signaling: "NONE",
                    color_metadata: "INSERT",
                    adaptive_quantization: "HIGH",
                    bitrate: 5000000,
                    entropy_encoding: "CABAC",
                    flicker_aq: "ENABLED",
                    framerate_control: "SPECIFIED",
                    framerate_numerator: 30,
                    framerate_denominator: 1,
                    gop_b_reference: "ENABLED",
                    gop_closed_cadence: 1,
                    gop_num_b_frames: 3,
                    gop_size: 60,
                    gop_size_units: "FRAMES",
                    scan_type: "PROGRESSIVE",
                    level: "H264_LEVEL_AUTO",
                    look_ahead_rate_control: "HIGH",
                    num_ref_frames: 3,
                    par_control: "INITIALIZE_FROM_SOURCE",
                    profile: "HIGH",
                    rate_control_mode: "CBR",
                    syntax: "DEFAULT",
                    scene_change_detect: "ENABLED",
                    slices: 1,
                    spatial_aq: "ENABLED",
                    temporal_aq: "ENABLED",
                    timecode_insertion: "DISABLED"
                  }
                },
                height: 1080,
                name: "video_1080p30",
                respond_to_afd: "NONE",
                sharpness: 50,
                scaling_behavior: "DEFAULT",
                width: 1920
              },
              {
                codec_settings: {
                  h264_settings: {
                    afd_signaling: "NONE",
                    color_metadata: "INSERT",
                    adaptive_quantization: "HIGH",
                    bitrate: 3000000,
                    entropy_encoding: "CABAC",
                    flicker_aq: "ENABLED",
                    framerate_control: "SPECIFIED",
                    framerate_numerator: 30,
                    framerate_denominator: 1,
                    gop_b_reference: "ENABLED",
                    gop_closed_cadence: 1,
                    gop_num_b_frames: 3,
                    gop_size: 60,
                    gop_size_units: "FRAMES",
                    scan_type: "PROGRESSIVE",
                    level: "H264_LEVEL_AUTO",
                    look_ahead_rate_control: "HIGH",
                    num_ref_frames: 3,
                    par_control: "INITIALIZE_FROM_SOURCE",
                    profile: "HIGH",
                    rate_control_mode: "CBR",
                    syntax: "DEFAULT",
                    scene_change_detect: "ENABLED",
                    slices: 1,
                    spatial_aq: "ENABLED",
                    temporal_aq: "ENABLED",
                    timecode_insertion: "DISABLED"
                  }
                },
                height: 720,
                name: "video_720p30",
                respond_to_afd: "NONE",
                sharpness: 100,
                scaling_behavior: "DEFAULT",
                width: 1280
              },
              {
                codec_settings: {
                  h264_settings: {
                    afd_signaling: "NONE",
                    color_metadata: "INSERT",
                    adaptive_quantization: "HIGH",
                    bitrate: 1500000,
                    entropy_encoding: "CABAC",
                    flicker_aq: "ENABLED",
                    framerate_control: "SPECIFIED",
                    framerate_numerator: 30,
                    framerate_denominator: 1,
                    gop_b_reference: "ENABLED",
                    gop_closed_cadence: 1,
                    gop_num_b_frames: 3,
                    gop_size: 60,
                    gop_size_units: "FRAMES",
                    scan_type: "PROGRESSIVE",
                    level: "H264_LEVEL_AUTO",
                    look_ahead_rate_control: "HIGH",
                    num_ref_frames: 3,
                    par_control: "SPECIFIED",
                    par_numerator: 4,
                    par_denominator: 3,
                    profile: "MAIN",
                    rate_control_mode: "CBR",
                    syntax: "DEFAULT",
                    scene_change_detect: "ENABLED",
                    slices: 1,
                    spatial_aq: "ENABLED",
                    temporal_aq: "ENABLED",
                    timecode_insertion: "DISABLED"
                  }
                },
                height: 480,
                name: "video_480p30",
                respond_to_afd: "NONE",
                sharpness: 100,
                scaling_behavior: "STRETCH_TO_OUTPUT",
                width: 640
              },
              {
                codec_settings: {
                  h264_settings: {
                    afd_signaling: "NONE",
                    color_metadata: "INSERT",
                    adaptive_quantization: "HIGH",
                    bitrate: 750000,
                    entropy_encoding: "CABAC",
                    flicker_aq: "ENABLED",
                    framerate_control: "SPECIFIED",
                    framerate_numerator: 30,
                    framerate_denominator: 1,
                    gop_b_reference: "ENABLED",
                    gop_closed_cadence: 1,
                    gop_num_b_frames: 3,
                    gop_size: 60,
                    gop_size_units: "FRAMES",
                    scan_type: "PROGRESSIVE",
                    level: "H264_LEVEL_AUTO",
                    look_ahead_rate_control: "HIGH",
                    num_ref_frames: 3,
                    par_control: "SPECIFIED",
                    par_numerator: 4,
                    par_denominator: 3,
                    profile: "MAIN",
                    rate_control_mode: "CBR",
                    syntax: "DEFAULT",
                    scene_change_detect: "ENABLED",
                    slices: 1,
                    spatial_aq: "ENABLED",
                    temporal_aq: "ENABLED",
                    timecode_insertion: "DISABLED"
                  }
                },
                height: 240,
                name: "video_240p30",
                respond_to_afd: "NONE",
                sharpness: 100,
                scaling_behavior: "STRETCH_TO_OUTPUT",
                width: 320
              }
            ]
          },
          input_attachments: [
            {
              input_id: ml_in_id,
              input_settings: {
                network_input_settings: {
                  server_validation: "CHECK_CRYPTOGRAPHY_AND_VALIDATE_NAME"
                },
                source_end_behavior: "CONTINUE",
                input_filter: "AUTO",
                filter_strength: 1,
                deblock_filter: "DISABLED",
                denoise_filter: "DISABLED",
                audio_selectors: [],
                caption_selectors: [
                  {
                    selector_settings: {
                      embedded_source_settings: {
                        source_608_channel_number: 1,
                        source_608_track_number: 1,
                        convert_608_to_708: "DISABLED",
                        scte_20_detection: "OFF"
                      }
                    },
                    name: "EmbeddedSelector"
                  }
                ]
              }
            }
          ],
          input_specification: {
            codec: "AVC",
            resolution: "HD",
            maximum_bitrate: "MAX_10_MBPS"
          },
          role_arn: "arn:aws:iam::731521589805:role/MediaLiveAccessRole",
        }
        ml_channel = medialive.create_channel(req).channel

        genre_id = params[:stream][:genre_id]
        view_price = params[:stream][:view_price].to_i rescue 0

        @stream.assign_attributes(
          name: params[:stream][:name],
          description: params[:stream][:description] || '',
          genre_id: genre_id,
          view_price: view_price,
          cover: params[:stream][:cover],
          ml_channel_id: ml_channel.id,
          mp_channel_1_id: mp_channel_1.id,
          mp_channel_1_url: mp_channel_1_url,
          # mp_channel_1_username: mp_channel_1_username,
          # mp_channel_1_password: mp_channel_1_password,
          mp_channel_1_ep_1_id: mp_channel_1_ep_1.id,
          mp_channel_1_ep_1_url: mp_channel_1_ep_1_url,
          mp_channel_2_id: mp_channel_2.id,
          mp_channel_2_url: mp_channel_2_url,
          # mp_channel_2_username: mp_channel_2_username,
          # mp_channel_2_password: mp_channel_2_password,
          mp_channel_2_ep_1_id: mp_channel_2_ep_1.id,
          mp_channel_2_ep_1_url: mp_channel_2_ep_1_url,
          cf_domain: nil,
          status: Stream.statuses[:active]
        )
        if params[:stream][:assoc_type].present? && params[:stream][:assoc_id].present?
          @stream.assoc_id = params[:stream][:assoc_id]
          @stream.assoc_type = params[:stream][:assoc_type]
        end
        @stream.save!

        StreamStartWorker.perform_async(@stream.id)
      # rescue Aws::MediaLive::Errors::ServiceError => e
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

      extend_period = params[:stream][:extend_period].to_i rescue 0
      @stream.valid_period += extend_period if extend_period > 0

      @stream.attributes = permitted_attributes(@stream)
      @stream.save!

      Rails.logger.info("\n\n\n streams/:id/update: #{params[:stream][:assoc_type].present?}, #{params[:stream][:assoc_id].present?}\n\n\n")
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
        medialive = Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
        medialive.start_channel({
          channel_id: @stream.ml_channel_id
        })
        @stream.update_attributes(
          started_at: Time.now,
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
        @stream.update_attributes(stopped_at: Time.now, status: Stream.statuses[:active])
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
      payment = @stream.pay_view(
        viewer: current_user,
        amount: params[:amount].to_i || 0,
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
