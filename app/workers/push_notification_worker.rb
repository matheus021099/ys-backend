class PushNotificationWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: 'high'

  def perform(user_push_tokens, type, message, data = {}, icon = nil, title = 'YouSound')
    @fcm_service ||= FCMService.new
    @fcm_service.send_push(user_push_tokens, type, message, data, icon, title)
  end
end
