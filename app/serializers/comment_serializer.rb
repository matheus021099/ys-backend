class CommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :status, :created_at, :commentable_type
  attribute :commentable, if: :include_commentable?
  attribute :readable_user_ids, if: :include_readers?

  belongs_to :user, if: :include_commenter?

  def commentable
    case object.commentable_type
      when 'Album'
        object.commentable.as_json(
          only: [ :id, :slug, :name, :cover, :album_type ]
        )
      when 'Post'
        object.commentable.as_json(
          only: [ :id, :cover, :media_name ]
        )
      when 'ShopProduct'
        object.commentable.as_json(
          only: [ :id, :name, :cover ]
        )
    end
  end

  def include_commenter?
    instance_options[:include_commenter] || false
  end

  def include_commentable?
    instance_options[:include_commentable] || false
  end

  def include_readers?
    instance_options[:include_readers] || false
  end
end
