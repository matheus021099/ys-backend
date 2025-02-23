class StreamSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :cover, :started_at, :stopped_at, :status, :mp_channel_1_ep_1_url,
    :valid_period, :remaining_seconds, :assoc_type, :account_ids, :digital_content_name,
    :view_price, :viewers_limit, :notified
  attribute :assoc
  attribute :guests
  attribute :ml_input_id, if: :is_current_user?
  attribute :ml_input_dest_1_url, if: :is_current_user?
  attribute :is_reposted
  attribute :broadcast_seconds
  attribute :digital_content_url
  attribute :accounts

  belongs_to :user
  belongs_to :genre
  # attribute :user
  # def user
  #   ActiveModel::Serializer::UserSerializer.new(object.user, scope: scope)
  # end

  def assoc
    return nil unless object.assoc_type.present?

    case object.assoc_type
      when 'Album'
        AlbumSerializer.new(
          object.assoc,
          scope: scope,
          include_collaborators: true,
          include_collaborators_user: true
        )
      when 'ShopProduct'
        ShopProductSerializer.new(
          object.assoc,
          scope: scope,
          include_collaborators: true,
          include_collaborators_user: true
        )
      when 'User'
        UserSerializer.new(
          object.assoc,
          scope: scope
        )
    end
  end

  def guests
    ActiveModel::Serializer::CollectionSerializer.new(
      User.where(id: object.guest_list),
      serializer: UserSerializer,
      scope: scope
    )
  end

  def accounts
    user_ids = object.account_ids || []
    users = User.where(id: user_ids).order("id = #{object.user_id} DESC")
    ActiveModelSerializers::SerializableResource.new(
      users,
      each_serializer: UserSerializer1,
      scope: OpenStruct.new(current_user: scope&.current_user),
      include_is_following: true
    )
  end

  def is_reposted
    if scope && scope.current_user
      Feed.where(
        consumer_id: scope.current_user.id,
        publisher_id: scope.current_user.id,
        assoc_type: object.class.name,
        assoc_id: object.id,
        feed_type: Feed.feed_types[:repost]
      ).size > 0
    else
      nil
    end
  end

  def broadcast_seconds
    (Time.now - object.started_at).to_i rescue 0
  end

  # def remaining_seconds
  #   return object.valid_period if object.started_at.blank?
  #   return object.valid_period - (Time.now - object.started_at).to_i
  # end

  def is_current_user?
    scope && scope.current_user == object.user
  end
end
