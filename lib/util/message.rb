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

      conversation = Mailboxer::Conversation.where(
        "subject = ? or subject = ?",
        [sender.id, receiver.id].join(', '),
        [receiver.id, sender.id].join(', ')
      ).first

      if conversation.present? && conversation.last_message.blank?
        conversation.destroy
        conversation = nil
      end

      conversation
    end

    def send(sender, receiver, message_body, message_subject = nil, attachment = nil, notification_type = nil)
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

      notification_type ||= FCMService::push_notification_types[:message_sent]

      PushNotificationWorker.perform_async(
        receiver.devices.where(enabled: true).pluck(:token),
        notification_type,
        message_body,
        MessageSerializer1.new(
          scope: OpenStruct.new(current_user: sender)
        ).serialize(receipt.message).as_json,
        nil,
        sender.display_name
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

    def remove_conversation(conversation_id)
      conversation = Mailboxer::Conversation.find(conversation_id)
      # find all receipts for specific conversation, if user received message it'll be in his/her inbox and he/she will be receiver, if user sent message it'll be in his/her sentbox and he/she will be sender.
      receipts = Mailboxer::Receipt.conversation(conversation).where('((receiver_id=? and mailbox_type=?) or (sender_id=? and mailbox_type=?))', current_user.id, 'inbox', current_user.id, 'sentbox')
      receipts.destroy_all # delete all messages (conversation maybe more than one message)
      if conversation.participants.count == 0 # if all participants deleted this conversation
        message_ids = conversation.messages.pluck(:id)
        conversation.messages.destroy_all     # destroy all conversation's messages
        conversation.destroy                  # destroy the conversation
        Attachment.where(mailboxer_notification_id: message_ids).destroy_all
        # puts "\n\n"
        # p message_ids
        # puts "\n\n\n"
      end

      def remove_all_conversation_by_user(user_id)
        conversation_ids = Mailboxer::Notification.joins(:receipts).where(mailboxer_receipts: {receiver_id: user_id}).pluck(:conversation_id).uniq
        notification_ids = Mailboxer::Notification.where(conversation_id: conversation_ids).pluck(:id)
        Mailboxer::Conversation.where(id: conversation_ids).destroy_all
        Attachment.where(mailboxer_notification_id: notification_ids)
      end
    end
  end
end
