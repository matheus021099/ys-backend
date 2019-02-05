class StreamsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:stream_id]}"
  end

  def unsubscribed
  end
end
