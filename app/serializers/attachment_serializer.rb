class AttachmentSerializer < ActiveModel::Serializer
  attributes :id, :attachment_type, :attachable_type, :status
  attribute :assoc

  def assoc
    return nil if object.attachable_type.blank?

    assoc = object.attachable_type.constantize.find_by(id: object.attachable_id)

    case object.attachable_type
      when 'Album'
        AlbumSerializer.new(
          assoc,
          scope: scope,
          include_collaborators: object.attachment_type == Attachment.attachment_types[:collaboration],
          include_collaborators_user: true
        )
      when 'ShopProduct'
        ShopProductSerializer.new(
          assoc,
          scope: scope,
          include_collaborators: object.attachment_type == Attachment.attachment_types[:collaboration],
          include_collaborators_user: true
        )
      when 'User'
        UserSerializer.new(
          assoc,
          scope: scope
        )
    end
  end
end