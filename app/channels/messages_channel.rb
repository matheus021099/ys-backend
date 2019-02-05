class MessagesChannel < ApplicationCable::Channel
  def subscribed
    stream_from "message_#{current_user.id}"
  end

  def unsubscribed
  end
end
