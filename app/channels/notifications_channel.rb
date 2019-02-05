class NotificationsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "notification_#{current_user.id}"
  end

  def unsubscribed
  end
end
