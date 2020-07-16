class UserSerializer1 < ActiveModel::Serializer
  attributes :id, :slug, :username, :display_name, :user_type, :avatar
  attribute :stripe_connected
  attribute :is_following, if: :include_is_following?
  attribute :recent_items, if: :include_recent?

  def stripe_connected
    object.stripe_connected?
  end

  def is_following
    if scope && scope.current_user
      return scope.current_user.following?(object)
    else
      return nil
    end
  end

  def recent_items
    filter = 'any'
    filter = 'uploaded' if instance_options[:include_recent_uploaded]
    filter = 'reposted' if instance_options[:include_recent_reposted]
    filter = 'downloaded' if instance_options[:include_recent_downloaded]
    filter = 'playlist' if instance_options[:include_recent_playlist]
    filter = 'merch' if instance_options[:include_recent_merch]
    filter = 'video' if instance_options[:include_recent_video]

    feeds = object.recent_items(scope&.current_user, filter, instance_options[:recent_count] || 4)
    if feeds.size > 0
      # ActiveModel::Serializer::CollectionSerializer.new(
      #   feeds,
      #   serializer: FeedSerializer,
      #   scope: scope,
      #   include_publisher: true
      # )
      ActiveModelSerializers::SerializableResource.new(
        feeds,
        each_serializer: FeedSerializer,
        scope: scope,
        include_publisher: true
      )
    end
  end

  def include_is_following?
    instance_options[:include_is_following] || false
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
end
