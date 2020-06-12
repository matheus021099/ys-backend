class CommentSerializer < ActiveModel::Serializer
  attributes :id, :body, :status, :created_at, :commentable_type
  attribute :commentable, if: :include_commentable?
  attribute :readable_user_ids, if: :include_readers?
  # belongs_to :user, if: :include_commenter?
  attribute :user, if: :include_commenter?

  def commentable
    Util::Serializer.polymophic_serializer(object.commentable)
  end

  def user
    UserSerializer1.new(object.user, scope: scope)
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
