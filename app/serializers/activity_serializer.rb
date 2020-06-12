class ActivitySerializer < ActiveModel::Serializer
  attributes :module_type, :action_type, :alert_type, :assoc_type, :assoc_id, :message, :status, :created_at, :updated_at
  attribute :assoc

  attribute :sender
  # belongs_to :sender
  belongs_to :receiver, if: :include_receiver?

  #TODO - serialization_scope :view_contex in application_controller
  def include_receiver?
    # puts '+++++'
    # puts scope
    # puts scope.current_user
    scope.current_user != object.receiver
  end

  def sender
    UserSerializer1.new(object.sender, scope: scope, include_recent: true, recent_count: 3)
  end

  def assoc
    return nil unless object.assoc
    case object.assoc_type
      when 'Album'
        AlbumSerializer.new(object.assoc, scope: scope)
      when 'ShopProduct'
        ShopProductSerializer.new(object.assoc, scope: scope)
      when 'Comment'
        CommentSerializer.new(object.assoc, scope: scope, include_commentable: true)
    end
  end
end
