# serializer for PN
class MessageSerializer1 < Panko::Serializer
  attributes :id, :body, :created_at
  attributes :attachment
  attributes :sender
  attributes :receiver

  def attachment
    attach = Attachment.attachments_for(object).first
    return nil unless attach.present?

    attach_json = attach.as_json(
      only: [ :id, :attachment_type, :attachable_type, :status ]
    )
    attach_json[:assoc] = Util::Serializer.polymophic_serializer(attach.attachable)

    attach_json
  end

  def sender
    UserSerializer1.new(
      object.sender,
      scope: scope
    )
  end

  def receiver
    # receiver = object.recipients.select{ |u| u.id != object.sender_id }.first
    return nil unless context&.receiver
    UserSerializer1.new(
      context.receiver,
      scope: scope
    )
  end
end
