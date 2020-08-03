class MessageChecker
  include Sidekiq::Worker

  sidekiq_options queue: 'low', unique: :until_and_while_executing

  def perform
    repost_request_cancel
  end

  def repost_request_cancel
    now = Time.now.utc
    started_date = now.ago(1.days)
    Attachment.includes(:message).where(
      attachment_type: Attachment.attachment_types[:repost],
      status: Attachment.statuses[:pending]
    ).where('updated_at < ?', started_date).each do |attachment|
      attachment.auto_cancel
      attachment.message.update_attributes(body: 'Automatically canceled due to a day of delay')
    end
    # .update_all(
    #   body: 'Automatically canceled due to 3 days of delay',
    #   status: Attachment.statuses[:canceled],
    #   updated_at: now
    # )
  end
end
