require 'fcm'

class FCMService
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
