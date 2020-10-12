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
    channel_name = "stream_#{stream_id}"
    page_track = "Stream: #{stream_id}"
    active_viewers_size = ActionCable.server.pubsub.send(:redis_connection).pubsub('numsub', channel_name).dig(1) || 0
    total_viewers_size = Activity.where('sender_id = receiver_id').where(
      page_track: page_track,
      action_type: Activity.action_types[:view_stream]
    ).size

    stream.checkpoint(
      Time.now,
      active_viewers_size,
      total_viewers_size
    )
  end
end
