class FeedSerializer < ActiveModel::Serializer
  attributes :id, :feed_type, :assoc_id, :assoc_type, :consumer_id, :publisher_id, :status, :created_at, :updated_at
  attribute :publisher, if: :include_publisher?
  attribute :assoc, unless: :exclude_assoc?

  def assoc
    # object.assoc
    case object.assoc_type
      when 'Album'
        ActiveModel::Serializer::AlbumSerializer.new(
          object.assoc,
          scope: scope,
          include_collaborators: true,
          include_collaborators_user: true
        )
      when 'ShopProduct'
        ActiveModel::Serializer::ShopProductSerializer.new(
          object.assoc,
          scope: scope,
          include_collaborators: true,
          include_collaborators_user: true
        )
      when 'Stream'
        ActiveModel::Serializer::StreamSerializer.new(object.assoc, scope: scope)
      when 'Comment'
        CommentSerializer.new(object.assoc, scope: scope)
    end
  end

  def publisher
    ActiveModel::Serializer::UserSerializer.new(
      object.publisher,
      scope: scope,
      include_social_info: false
    )
  end

  def include_publisher?
    instance_options[:include_publisher] || false
  end

  def exclude_assoc?
    instance_options[:exclude_assoc] || false
  end
end
