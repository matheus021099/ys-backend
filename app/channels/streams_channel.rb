class StreamsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:stream_id]}"
    send_channel_info params[:stream_id], 1
  end

  def unsubscribed
    send_channel_info params[:stream_id], -1
  end

  def send_channel_info(stream_id, additional_viewers)
    stream = Stream.find(stream_id)
    page_track = "Stream: #{stream_id}"
    # channel_name = "stream_#{stream_id}"
    # active_viewers_size = ActionCable.server.pubsub.send(:redis_connection).pubsub('numsub', channel_name).dig(1) || 0
    active_viewers_size = stream.watching_viewers + additional_viewers > 0 ? stream.watching_viewers + additional_viewers : 0
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
