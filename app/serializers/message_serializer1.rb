# serializer for PN
class MessageSerializer1 < Panko::Serializer
  attributes :id, :body, :created_at
  attributes :attachment

  def attachment
    attach = Attachment.attachments_for(object).first
    return nil unless attach.present?

    attach_json = attach.as_json(
      only: [ :id, :attachment_type, :attachable_type, :status ]
    )
    attach_json[:assoc] = Util::Serializer.polymophic_serializer(attach.attachable)

    attach_json
  end
end
