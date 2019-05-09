# used in profile controller
class FeedSerializer1 < Panko::Serializer
  attributes :id, :feed_type, :assoc_id, :assoc_type
  attributes :assoc

  def assoc
    case object.assoc_type
      when 'Album'
        AlbumSerializer1.new(scope: scope).serialize(object.assoc)
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
end
