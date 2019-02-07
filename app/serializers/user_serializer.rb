class UserSerializer < ActiveModel::Serializer
  attributes :id, :slug, :username, :display_name, :first_name, :last_name, :contact_url, :user_type,
    :avatar, :repost_price, :repost_price_end_at,
    :status, :size_chart, :shipping_policy, :return_policy, :privacy_policy
  attribute :followers
  attribute :followings
  attribute :email, if: :include_social_info?
  attribute :enable_alert, if: :is_current_user?
  attribute :enabled_live_video, if: :include_social_info?
  attribute :enabled_live_video_free, if: :include_social_info?
  attribute :balance_amount, if: :is_current_user?
  attribute :available_amount, if: :is_current_user?
  attribute :is_stripe_connected, if: :is_current_user?
  attribute :message_first_visited_time, if: :is_current_user?
  attribute :sign_in_count, if: :is_current_user?
  attribute :stream_rolled_time, if: :is_current_user?
  attribute :stream_rolled_cost, if: :is_current_user?
  attribute :stream, if: :include_all?
  attribute :enabled_view_direct_messages, if: :is_moderator?


  # is following by current_user
  attribute :is_following
  # is follower to current_user
  # attribute :is_follower

  belongs_to :approver, if: :include_social_info?
  attribute :approved_at, if: :include_social_info?
  belongs_to :inviter
  attribute :invited_at
  attribute :created_at, if: :include_social_info?
  attribute :free_streamed_time, if: :include_social_info?
  attribute :free_stream_seconds, if: :include_social_info?
  attribute :demand_stream_seconds, if: :include_social_info?
  # attribute :social_provider, if: :include_social_info?
  attribute :social_user_id, if: :include_social_info?
  # attribute :social_user_name, if: :include_social_info?
  # attribute :social_token, if: :include_social_info?
  # attribute :social_token_secret, if: :include_social_info?

  attribute :request_role, if: :include_social_info?
  attribute :request_status, if: :include_social_info?

  attribute :genre_id, if: :include_social_info?
  belongs_to :genre, if: :include_social_info?
  attribute :year_of_birth, if: :include_social_info?
  attribute :gender, if: :include_social_info?
  attribute :country, if: :include_social_info?
  attribute :city, if: :include_social_info?
  attribute :artist_type, if: :include_social_info?
  attribute :released_albums_count, if: :include_social_info?
  attribute :years_since_first_released, if: :include_social_info?
  attribute :will_run_live_video, if: :include_social_info?
  attribute :will_sell_products, if: :include_social_info?
  attribute :will_sell_physical_copies, if: :include_social_info?
  attribute :annual_income_on_merch_sales, if: :include_social_info?
  attribute :annual_performances_count, if: :include_social_info?
  attribute :signed_status, if: :include_social_info?
  attribute :performance_rights_organization, if: :include_social_info?
  attribute :ipi_cae_number, if: :include_social_info?
  attribute :website_1_url, if: :include_social_info?
  attribute :website_2_url, if: :include_social_info?
  attribute :sub_genre_id, if: :include_social_info?
  attribute :is_business_registered, if: :include_social_info?
  attribute :artists_count, if: :include_social_info?
  attribute :standard_brand_type, if: :include_social_info?
  attribute :customized_brand_type, if: :include_social_info?
  attribute :employees_count, if: :include_social_info?
  attribute :years_in_business, if: :include_social_info?
  attribute :will_sell_music_related_products, if: :include_social_info?
  attribute :products_count, if: :include_social_info?
  attribute :annual_income, if: :include_social_info?
  attribute :history, if: :include_social_info?

  attribute :denial_reason, if: :include_social_info?
  attribute :denial_description, if: :include_social_info?

  attribute :hidden_genres, if: :include_all?
  attribute :blocked_users, if: :include_all?
  attribute :favorite_users, if: :include_all?
  attribute :default_address, if: :include_all?

  # attribute :reposted_feeds, if: :include_reposted?

  attribute :recent_items, if: :include_recent?

  # def attributes(*names)
  #   hash = super
  #   puts '++++++++'
  #   puts instance_options
  #   puts hash
  #   hash
  # end

  def is_moderator?
    include_social_info? && object.user_type == 'moderator'
  end

  def is_current_user?
    scope && scope.current_user == object
  end

  def is_stripe_connected
    object.stripe_connected?
  end

  def followers
    return object.followers_count
  end

  def followings
    return object.follow_count
  end

  def is_following
    if scope && scope.current_user
      return scope.current_user.following?(object)
    else
      # puts "\n\t\t\t is_following scope.current_user is not set\n\n"
      return nil
    end
  end

  def stream
    unless object.stream.nil?
      ActiveModel::Serializer::StreamSerializer.new(object.stream, scope: scope)
    end
  end

  def hidden_genres
    # object.hidden_genre_objects
    ActiveModel::Serializer::CollectionSerializer.new(object.hidden_genre_objects, serializer: GenreSerializer)
  end

  def blocked_users
    # object.blocked_user_objects
    ActiveModel::Serializer::CollectionSerializer.new(object.blocked_user_objects, serializer: UserSerializer, scope: scope)
  end

  def favorite_users
    ActiveModel::Serializer::CollectionSerializer.new(object.favorite_user_objects, serializer: UserSerializer, scope: scope)
  end

  def default_address
    # object.default_address
    unless object.default_address.nil?
      ActiveModel::Serializer::ShopAddressSerializer.new(object.default_address)
    end
  end

  def free_streamed_time
    object.free_streamed_time + (object.stream && object.stream.running? ? (Time.now - object.stream.started_at).to_i : 0)
  end

  def free_stream_seconds
    # User.connection.execute("SELECT SUM(CAST(message as INTEGER)) FROM activities").to_s
    Activity.where(
      sender_id: object.id,
      receiver_id: object.id,
      action_type: Activity.action_types[:free_host_stream]
    ).select(:message).pluck(:message).inject(0){ |s, m| s += m.to_i }
  end

  def demand_stream_seconds
    Activity.where(
      sender_id: object.id,
      receiver_id: object.id,
      action_type: Activity.action_types[:demand_host_stream]
    ).select(:message).pluck(:message).inject(0){ |s, m| s += m.to_i }
  end

  def recent_items
    filter = 'any'
    filter = 'uploaded' if instance_options[:include_recent_uploaded]
    filter = 'reposted' if instance_options[:include_recent_reposted]
    filter = 'downloaded' if instance_options[:include_recent_downloaded]
    filter = 'playlist' if instance_options[:include_recent_playlist]
    filter = 'merch' if instance_options[:include_recent_merch]
    filter = 'video' if instance_options[:include_recent_video]

    feeds = object.recent_items(scope.current_user, filter, instance_options[:recent_count] || 5)
    if feeds.size > 0
      ActiveModel::Serializer::CollectionSerializer.new(
        feeds,
        serializer: FeedSerializer,
        scope: scope,
        include_publisher: true
      )
    end
  end

  def reposted_feeds
    feeds = object.repost_query(nil, nil)

    ActiveModel::Serializer::CollectionSerializer.new(
      feeds,
      serializer: FeedSerializer,
      scope: scope,
      exclude_assoc: true
    )
  end

  # def include_stream_info?
  #   instance_options[:include_stream_info] || false
  # end

  def include_social_info?
    # puts instance_options
    instance_options[:include_social_info] || false
  end

  def include_all?
    instance_options[:include_all] || false
  end

  def include_recent?
    instance_options[:include_recent] ||
    instance_options[:include_recent_uploaded] ||
    instance_options[:include_recent_reposted] ||
    instance_options[:include_recent_downloaded] ||
    instance_options[:include_recent_playlist] ||
    instance_options[:include_recent_merch] ||
    instance_options[:include_recent_video] || false
  end

  def include_reposted?
    instance_options[:include_reposted] || false
  end
end
