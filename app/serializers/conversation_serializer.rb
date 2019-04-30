class ConversationSerializer < ActiveModel::Serializer
  attributes :id, :created_at
  attribute :other
  # has_many :messages, if: :include_messages?
  # attribute :messages, if: :include_messages?
  attribute :last_message#, unless: :include_messages?

  # def attributes
  #   # if @show_details
  #   #   super.except(:last_message)
  #   # else
  #   #   super.except(:messages)
  #   # end
  #   base_attributes = serialization_options[:include_all].present? ? super.merge(messages: object.messages) : super
  # end
  
  # def messages
  #   return [] unless scope && scope.current_user && scope.user
  #   messages = Mailboxer::Notification.joins(:receipts).where(
  #     conversation_id: object.id
  #   ).order(updated_at: :desc)
  #   if scope.current_user.admin? || (scope.current_user.moderator? && scope.current_user.enabled_view_direct_messages)
  #     messages = messages.where(
  #       mailboxer_receipts: {
  #         receiver_id: scope.user.id
  #       }
  #     )
  #   else
  #     messages = messages.where(
  #       mailboxer_receipts: {
  #         receiver_id: scope.user.id,
  #         deleted: false
  #       }
  #     )
  #   end
  #   ActiveModel::Serializer::CollectionSerializer.new(
  #     messages,
  #     serializer: MessageSerializer,
  #     scope: scope
  #   )
  # end

  def last_message
    MessageSerializer.new(
      object.last_message,
      scope: scope
    )
  end

  def other
    object.participants.each do |participant|
      if participant.id != scope.user.id
        return UserSerializer.new(
          participant,
          scope: scope,
          # include_reposted: true,
          include_all: true
        )
      end
    end
  end

  # def users
  #   ActiveModel::Serializer::CollectionSerializer.new(
  #     object.participants,
  #     serializer: UserSerializer,
  #     scope: scope
  #   )
  # end

  # def include_messages?
  #   instance_options[:include_messages] || false
  # end
end
