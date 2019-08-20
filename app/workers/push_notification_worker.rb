class PushNotificationWorker
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: 'high'

  def perform(user_push_tokens, message, users, data = {}, icon = nil, title = 'YouSound')
    # if users['receiver_id'].is_a?(Array)
    #   return if users['receiver_id'].empty?
    #   users['receiver_id'].each do |receiver_id|
    #     create_notification(
    #       nil,
    #       receiver_id,
    #       message,
    #       data
    #     )
    #   end
    # else
    #   return unless users['receiver_id'].present?
    #   create_notification(
    #     users['sender_id'],
    #     users['receiver_id'],
    #     message,
    #     data
    #   )
    # end

    @fcm_service ||= FCMService.new
    @fcm_service.send_push(user_push_tokens, message, data, icon, title)
  end

  # private
  # def create_notification(sender_id, receiver_id, message, data_message)
  #   Notification.create(
  #     sender_id: sender_id,
  #     receiver_id: receiver_id,
  #     message: message,
  #     data_message: data_message
  #   )
  # end
end
