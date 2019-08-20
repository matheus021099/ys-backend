require 'fcm'

class FCMService
  def send_push(user_push_tokens, message, data = {}, icon = nil, title = 'YouSound')
    @title = title
    @message = message
    @icon = icon
    @data = data

    user_push_tokens = [user_push_tokens] if user_push_tokens.is_a?(String)
    # options = platform.eql?('ios') ? prepare_ios_options : prepare_options
    response = fcm.send(user_push_tokens, options)
    response
  end

  private

  def fcm
    @fcm ||= FCM.new(api_key)
  end

  def api_key
    $env.firebase.authorization
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
