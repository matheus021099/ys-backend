class MessageSerializer < ActiveModel::Serializer
  attributes :id, :body, :created_at
  attribute :is_read
  attribute :sender
  attribute :attachment

  # belongs_to :conversation

  def is_read
    object.is_read?(scope.user)
  end

  def sender
    UserSerializer.new(
      object.sender,
      scope: scope
    )
  end

  def attachment
    attach = Attachment.attachments_for(object).first
    return nil unless attach.present?

    AttachmentSerializer.new(
      attach,
      scope: scope
    )
  end

  def include_sender?
    instance_options[:include_sender] || false
  end
end
