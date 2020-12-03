class StreamsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:stream_id]}"
    # send_channel_info params[:stream_id], 1
  end

  def unsubscribed
    # send_channel_info params[:stream_id], -1
  end

  # def send_channel_info(stream_id, additional_viewers)
  #   stream = Stream.find(stream_id)
  #   stream.checkpoint
  # end
end
