class StreamsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:stream_id]}"
    send_channel_info params[:stream_id]
  end

  def unsubscribed
    send_channel_info params[:stream_id]
  end

  def send_channel_info(stream_id)
    stream = Stream.find(stream_id)
    stream.checkpoint
  end
end
