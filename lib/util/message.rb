class Util::Message
  class << self
    def get_conversation(sender, receiver)
      # conversations = sender.mailbox.conversations
      # conversations.each do |conversation|
      #   if (sender.id == conversation.participants[0].id && receiver.id == conversation.participants[1].id) ||
      #       (sender.id == conversation.participants[1].id && receiver.id == conversation.participants[0].id)
      #     return conversation
      #   end
      # end
      # nil

      Mailboxer::Conversation.where(
        "subject = ? or subject = ?",
        [sender.id, receiver.id].join(', '),
        [receiver.id, sender.id].join(', ')
      ).first
    end

    def send(sender, receiver, message_body, message_subject = nil, attachment = nil)
      # message_subject ||= 'Message'
      message_subject = [sender.id, receiver.id].join(', ') if message_subject.blank?
      receipt = nil
      conversation = self.get_conversation(sender, receiver)
      if conversation.blank?
        receipt = sender.send_message(receiver, message_body, message_subject, false)
      else
        receipt = sender.reply_to_conversation(conversation, message_body, nil, true, false)
      end

      # unless attachment.nil?
      if attachment.present?
        attachment.mailboxer_notification_id = receipt.message.id
        attachment.save!
      end

      # PushNotificationWorker.new.perform(
      PushNotificationWorker.perform_async(
        receiver.devices.where(enabled: true).pluck(:token),
        'MESSAGE_RECEIVED',
        message_body,
        MessageSerializer.new(
          receipt.message,
          scope: OpenStruct.new(current_user: sender)
        ).as_json
      )

      self.broadcast(receipt.message)
      ActionCable.server.broadcast("notification_#{receiver.id}", {message: 1})

      receipt
    end

    def broadcast(message)
      message.recipients.each do |user|
        message_json = MessageSerializer.new(
          message,
          scope: OpenStruct.new(current_user: user)
        ).as_json

        ActionCable.server.broadcast("message_#{user.id}", message_json)
      end
    end
  end
end
