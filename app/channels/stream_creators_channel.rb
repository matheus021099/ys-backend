class StreamCreatorsChannel < ApplicationCable::Channel
  def subscribed
    stream_id = params[:stream_id]
    channel_name = "stream_creator_#{stream_id}"
    stream_from channel_name

    stream = Stream.find(stream_id)
    ActionCable.server.broadcast(channel_name, {
      active_viewers_size: stream.watching_viewers,
      total_viewers_size: stream.total_viewers,
      remaining_seconds: stream.remaining_seconds
    })
  end

  def unsubscribed
  end
end
