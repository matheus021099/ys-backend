class Attachment < ApplicationRecord
  # enum status: ['pending', 'accepted', 'denied', 'canceled']
  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied',
    canceled: 'canceled'
  }
  enum attachment_type: {
    repost: 'repost',
    collaboration: 'collaboration',
    label_user: 'label_user',
    label_album: 'label_album',
    sample_album: 'sample_album'
  }

  belongs_to :attachable, polymorphic: true
  belongs_to :message, foreign_key: 'mailboxer_notification_id', class_name: 'Mailboxer::Notification'

  scope :attachments_for, ->(message=nil) { where(mailboxer_notification_id: message.id) if message }

  # default
  after_initialize :set_default_values
  def set_default_values
    self.status ||= Attachment.statuses[:pending]
  end

  after_update :do_after_update
  def do_after_update
    Util::Message.broadcast(self.message)
  end

  def accept(sender: nil, receiver: nil)
    Payment.accept_repost_request(
      sender: sender,
      receiver: receiver,
      assoc_type: self.attachable_type,
      assoc_id: self.attachable_id,
      attachment_id: self.id
    )
    self.update_attributes(status: Attachment.statuses[:accepted])
  end

  # def repost_deny
  def deny(sender: nil, receiver: nil)
    Payment.deny_repost_request(
      # sender: sender,
      # receiver: receiver,
      assoc_type: self.attachable_type,
      assoc_id: self.attachable_id,
      attachment_id: self.id
    )
    self.update_attributes(status: Attachment.statuses[:denied])
  end

  def auto_cancel(sender: nil, receiver: nil)
    Payment.deny_repost_request(
      assoc_type: self.attachable_type,
      assoc_id: self.attachable_id,
      attachment_id: self.id
    )
    self.update_attributes(status: Attachment.statuses[:canceled])
  end

  def accept_on_free(sender: nil, receiver: nil)
    Payment.accept_repost_request_on_free(
      sender: sender,
      receiver: receiver,
      assoc_type: self.attachable_type,
      assoc_id: self.attachable_id,
      attachment_id: self.id
    )
    self.update_attributes(status: Attachment.statuses[:accepted])
  end

  def self.find_pending(sender: nil, receiver: nil, attachment_type: '', attachable: nil)
    # Attachment
    #   .joins("LEFT JOIN mailboxer_notifications t2 ON t2.id = attachments.mailboxer_notification_id "\
    #     "LEFT JOIN mailboxer_receipts t3 ON t2.id = t3.notification_id")
    #   .where(
    #     attachment_type: attachment_type,
    #     attachable_type: attachable.class.name,
    #     attachable_id: attachable.id,
    #     status: Attachment.statuses[:pending])
    #   .where("t2.sender_id = ? AND t3.receiver_id = ?", sender.id, receiver.id)
    #   .first

    self.find_by_status(
      sender: sender,
      receiver: receiver,
      attachment_type: attachment_type,
      attachable: attachable,
      status: Attachment.statuses[:pending]
    )
  end

  def self.find_by_status(sender: nil, receiver: nil, attachment_type: '', attachable: nil, status: nil)
    attachments = Attachment.includes(:message)
      .joins("LEFT JOIN mailboxer_notifications t2 ON t2.id = attachments.mailboxer_notification_id "\
        "LEFT JOIN mailboxer_receipts t3 ON t2.id = t3.notification_id")
      .where(
        attachment_type: attachment_type,
        attachable_type: attachable.class.name,
        attachable_id: attachable.id)
      .where("t2.sender_id = ? AND t3.receiver_id = ?", sender.id, receiver.id)

    attachments = attachments.where(status: status) unless status.blank?

    attachments.first
  end
end
