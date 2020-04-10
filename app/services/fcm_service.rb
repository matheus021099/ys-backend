require 'fcm'

class FCMService
  def self.push_notification_types
    {
      user_followed: 'USER_FOLLOWED',
      user_donated: 'USER_DONATED',
      user_shared: 'USER_SHARED',
      video_started: 'VIDEO_STARTED',
      message_sent: 'MESSAGE_SENT',
      message_received: 'MESSAGE_RECEIVED',
      message_attachment_denied: 'MESSAGE_ATTACHMENT_DENIED',
      message_attachment_accepted: 'MESSAGE_ATTACHMENT_ACCEPTED',
      message_attachment_canceled: 'MESSAGE_ATTACHMENT_CANCELED',
      album_reposted: 'ALBUM_REPOSTED',
      product_purchased: 'PRODUCT_PURCHASED',
      product_reposted: 'PRODUCT_REPOSTED',
      commented: 'COMMENTED'
    }
  end

  def send_push(user_push_tokens, type, message, data = {}, icon = nil, title = 'YouSound')
    @title = title
    @message = message
    @icon = icon
    @data = data
    @data[:push_notification_type] = type

    user_push_tokens = [user_push_tokens] if user_push_tokens.is_a?(String)
    response = fcm.send(user_push_tokens, options)
    response
  end

  private

  def fcm
    @fcm ||= FCM.new(api_key)
  end

  def api_key
    ENV['FCM_SERVER_KEY']
  end

  def options
    {
      priority: 'high',
      data: @data,
      notification: {
        title: @title,
        body: @message,
        icon: @icon
      }
    }
  end
end
