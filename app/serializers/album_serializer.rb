class AlbumSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :description, :cover, :album_type,
    :collaborators_count, :status, :genres, :is_only_for_live_stream,
    :is_content_acapella, :is_content_instrumental, :is_content_stems, :is_content_remix, :is_content_dj_mix,
    :recommended, :played, :downloaded, :reposted, :commented, :enabled_sample,
    :created_at, :released_at, :recommended_at, :location
  attributes :tracks
  # has_many :tracks
  attribute :products, if: :include_product?
  attribute :collaborators, if: :include_collaborators?
  attribute :can_edit_collaborators, if: :include_collaborators?
  attribute :contributors, if: :include_contributors?
  attribute :labels, if: :include_labels?
  attribute :samplings, if: :include_samplings?
  # attribute :is_reposted

  # belongs_to :user
  attribute :user

  def user
    ActiveModel::Serializer::UserSerializer.new(
      object.user,
      scope: scope,
      include_recent_reposted: instance_options[:include_user_recent],
      recent_count: 4
    )
  end

  def genres
    if object.genre_objects
      ActiveModel::Serializer::CollectionSerializer.new(
        object.genre_objects,
        serializer: GenreSerializer,
        scope: scope
      )
    end
  end

  def tracks
    object.album_tracks.map{ |at|
      next unless at.present? && at.track.present?
      result = TrackSerializer.new(at.track, scope: scope, include_user: object.playlist?).as_json
      result['position'] = at.position
      result
    }.compact
  end

  def products
    if object.product_objects
      ActiveModel::Serializer::CollectionSerializer.new(
        object.product_objects,
        serializer: ShopProductSerializer,
        scope: scope,
        include_user: instance_options[:include_collaborators_user],
        include_collaborators: true,
        include_collaborators_user: true
      )
    end
  end

  def collaborators
    user_albums = object.user_albums.where(users_albums: { user_type: UserAlbum.user_types[:collaborator] })
    ActiveModel::Serializer::CollectionSerializer.new(
      user_albums,
      serializer: UserAlbumSerializer,
      scope: scope,
      include_user: instance_options[:include_collaborators_user]
    )
  end

  def contributors
    user_albums = object.user_albums.where(users_albums: { user_type: UserAlbum.user_types[:contributor] })
    ActiveModel::Serializer::CollectionSerializer.new(
      user_albums,
      serializer: UserAlbumSerializer,
      scope: scope,
      include_user: instance_options[:include_contributors_user]
    )
  end

  def labels
    user_albums = object.user_albums.where(users_albums: { user_type: UserAlbum.user_types[:label], status: UserAlbum.statuses[:accepted] })
    ActiveModel::Serializer::CollectionSerializer.new(
      user_albums,
      serializer: UserAlbumSerializer,
      scope: scope,
      include_user: instance_options[:include_labels_user]
    )
  end

  def samplings
    object.samplings.order(position: :asc)
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

  def include_meta?
    instance_options[:include_meta] || false
  end

  def include_product?
    instance_options[:include_product] || false
  end

  def include_collaborators?
    instance_options[:include_collaborators] || false
  end

  def include_contributors?
    instance_options[:include_contributors] || false
  end

  def include_labels?
    instance_options[:include_labels] || false
  end

  def include_samplings?
    instance_options[:include_samplings] || false
  end
end
