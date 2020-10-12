class Stream < ApplicationRecord
  acts_as_taggable_on :guests

  @@medialive = nil
  @@mediapackage = nil
  @@ssm = nil

  STREAM_PER_VIEWER_MINUTE_PRICE = 5.0
  STREAM_PER_MINUTE_PRICE = 5.8

  enum status: {
    active: 'active',
    starting: 'starting',
    running: 'running',
    inactive: 'inactive',
    deleted: 'deleted'
  }

  mount_uploader :cover, VideoCoverUploader

  belongs_to :user
  belongs_to :assoc, polymorphic: true, optional: true
  belongs_to :genre

  # default
  after_initialize :set_default_values
  def set_default_values
    self.viewers_limit ||= 2_000
  end

  def checkpoint(check_at, watching_viewers_size, total_viewers_size)
    stream = self
    user = stream.user

    check_at ||= Time.now
    prev_checkpoint_at = stream.checkpoint_at || stream.started_at
    interval = (check_at - prev_checkpoint_at).to_i
    per_sec_cost = (STREAM_PER_MINUTE_PRICE + stream.watching_viewers * STREAM_PER_VIEWER_MINUTE_PRICE) / 60
    cost = 0
    remaining_seconds = -1
    unless user.enabled_live_video_free
      cost =  stream.cost + per_sec_cost * interval
      remaining_seconds = ((user.stream_rolled_cost - cost) / per_sec_cost).to_i
      remaining_seconds = 0 if remaining_seconds < 0
    end

    stream.update_attributes(
      checkpoint_at: check_at,
      cost: cost,
      watching_viewers: watching_viewers_size,
      total_viewers: total_viewers_size,
      remaining_seconds: remaining_seconds
    )

    channel_name = "stream_#{stream.id}"
    ActionCable.server.broadcast(channel_name, {
      active_viewers_size: stream.watching_viewers,
      total_viewers_size: stream.total_viewers
    })

    true
  end

  def run
    now = Time.now
    self.update_attributes(
      started_at: now,
      checkpoint_at: now,
      status: Stream.statuses[:running]
    )
    checkpoint(now, 0, 0)

    Feed.insert(
      consumer_id: self.user_id,
      publisher_id: self.user_id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:release]
    )

    Activity.create(
      sender_id: self.user_id,
      receiver_id: self.user_id,
      message: 'broadcast a live stream',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:release],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    true
  end

  def notify
    self.update_columns(notified: true)

    ActionCable.server.broadcast("stream_#{self.id}", { notified: true })

    message_body = "#{self.user.username} broadcasting live!"
    data = self.as_json(
      only: [ :id, :user_id, :name, :cover ],
      include: {
        user: {
          only: [ :id, :slug, :name, :username, :avatar ]
        }
      }
    )
    data[:assoc] = Util::Serializer.polymophic_serializer(self.assoc)

    self.user.followers.each do |follower|
      next if follower.blank?

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: self.user_id,
        assoc_type: self.class.name,
        assoc_id: self.id,
        feed_type: Feed.feed_types[:release]
      )

      # if feed && follower.enable_alert
      #   Activity.create(
      #     sender_id: self.user_id,
      #     receiver_id: follower.id,
      #     message: 'updated your stream',
      #     assoc_type: self.class.name,
      #     assoc_id: self.id,
      #     module_type: Activity.module_types[:stream],
      #     action_type: Activity.action_types[:release],
      #     alert_type: Activity.alert_types[:both],
      #     status: Activity.statuses[:unread]
      #   )
      # end

      ### create streams/:id/notify and call it when stream is available
      PushNotificationWorker.perform_async(
        follower.devices.where(enabled: true).pluck(:token),
        FCMService::push_notification_types[:video_started],
        message_body,
        data
      )
    end

    true
  end

  def repost(reposter)
    return 'you are trying to repost your own live video' if reposter.id == self.user_id

    feed = Feed.insert(
      consumer_id: reposter.id,
      # publisher_id: self.user_id,
      publisher_id: reposter.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:repost]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: self.user_id,
      message: 'reposted your live video',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:unread]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: reposter.id,
      message: 'updated your stream',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:stream],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:unread]
    )

    reposter.followers.each do |follower|
      next if follower.blank?
      # item should not appear in possessor's stream page
      next if follower.id == self.user_id

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: reposter.id,
        assoc_type: self.class.name,
        assoc_id: self.id,
        feed_type: Feed.feed_types[:repost]
      )

      # if feed && follower.enable_alert?
      #   Activity.insert(
      #     sender_id: reposter.id,
      #     receiver_id: follower.id,
      #     message: 'updated your stream',
      #     assoc_type: self.class.name,
      #     assoc_id: self.id,
      #     module_type: Activity.module_types[:stream],
      #     action_type: Activity.action_types[:repost],
      #     alert_type: Activity.alert_types[:both],
      #     status: Activity.statuses[:unread]
      #   )
      # end
    end

    true
  end

  def can_view(viewer)
    @stream = self
    current_user = viewer

    return {
      code: true,
      message: 'Allowed'
    } if current_user.id == @stream.user_id

    # allow the user who paid with in a day
    payment = Payment.where(
      sender_id: current_user.id,
      receiver_id: self.user_id,
      payment_type: Payment.payment_types[:pay_view_stream],
      refund_amount: 0,
    ).where('created_at > ?', 1.day.ago).first
    return {
      code: true,
      message: 'Allowed'
    } unless payment.blank?

    page_track = "#{@stream.class.name}: #{@stream.id}"
    activity = Activity.where(
      sender_id: current_user.id,
      receiver_id: current_user.id,
      action_type: Activity.action_types[:view_stream],
      page_track: page_track
    ).first
    return {
      code: true,
      message: 'Allowed'
    } unless activity.blank?

    viewers_size = Activity.where('sender_id = receiver_id').where(
      page_track: page_track,
      action_type: Activity.action_types[:view_stream]
    ).size
    return {
      code: false,
      message: 'Exceeds the viewers limit',
      amount: 0
    } if @stream.viewers_limit > 0 && viewers_size >= @stream.viewers_limit

    return {
      code: true,
      message: 'Allowed'
    } if @stream.view_price == 0

    return {
      code: true,
      message: 'Allowed'
    } if @stream.guest_list.include?(current_user.id)

    payment = Payment.where(
      sender_id: current_user.id,
      receiver_id: @stream.user_id,
      payment_type: Payment.payment_types[:pay_view_stream],
      assoc_type: @stream.class.name,
      assoc_id: @stream.id,
      status: Payment.statuses[:done]
    ).first
    return {
      code: true,
      message: 'Allowed'
    } unless payment.blank?

    return {
      code: false,
      message: 'Need to pay',
      amount: @stream.view_price
    }
  end

  def view(viewer)
    ### #TODO call can_view to consider the case when 2 guests are about to view at the same time
    # result = self.can_view
    # return false unless result.code

    @stream = self
    current_user = viewer

    page_track = "#{@stream.class.name}: #{@stream.id}"
    activity = Activity.where(
      sender_id: current_user.id,
      receiver_id: current_user.id,
      action_type: Activity.action_types[:view_stream],
      page_track: page_track
    ).first

    if activity.blank?
      Activity.create({
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: 'viewed a stream',
        assoc_type: 'User',
        assoc_id: @stream.user_id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:view_stream],
        alert_type: Activity.alert_types[:both],
        page_track: page_track,
        status: Activity.statuses[:read]
      })

      ActionCable.server.broadcast("stream_#{@stream.id}", {views_size: 1})
    end
  end

  def remove
    @stream = self
    result = true
    was_running = @stream.running?
    now = Time.now

    # remove repost
    Activity.where(
      assoc_type: @stream.class.name,
      assoc_id: @stream.id
    ).delete_all

    Feed.where(
      assoc_type: @stream.class.name,
      assoc_id: @stream.id
    ).delete_all

    Util::Tag.remove(@stream.id)

    begin
      @@medialive ||= Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
      @@mediapackage ||= Aws::MediaPackage::Client.new(region: ENV['AWS_REGION'])
      @@ssm ||= Aws::SSM::Client.new(region: ENV['AWS_REGION'])

      if @stream.running? || @stream.starting?
        @@medialive.stop_channel({
          channel_id: @stream.ml_channel_id
        })
        @stream.stopped_at = now
      end

      @@medialive.delete_channel({
        channel_id: @stream.ml_channel_id
      })

      @@mediapackage.delete_origin_endpoint({
        id: @stream.mp_channel_2_ep_1_id
      })

      @@mediapackage.delete_origin_endpoint({
        id: @stream.mp_channel_1_ep_1_id
      })

      @@mediapackage.delete_channel({
        id: @stream.mp_channel_2_id
      })

      @@mediapackage.delete_channel({
        id: @stream.mp_channel_1_id
      })

      @@ssm.delete_parameters({
        names: [
          "/medialive/#{@stream.mp_channel_1_id}_user",
          "/medialive/#{@stream.mp_channel_2_id}_user"
        ]
      })

      ### error raised due to medialive_channal is in deleting
      # @@medialive.delete_input({
      #   input_id: @stream.ml_input_id
      # })
    rescue => e
      Rails.logger.info(e.message)
      result = e.message
      @stream.assign_attributes(
        status: Stream.statuses[:inactive]
      )
      @stream.save!
    else
      @stream.assign_attributes(
        mp_channel_1_id: nil,
        mp_channel_1_url: nil,
        mp_channel_1_ep_1_id: nil,
        mp_channel_1_ep_1_url: nil,
        mp_channel_2_id: nil,
        mp_channel_2_url: nil,
        mp_channel_2_ep_1_id: nil,
        mp_channel_2_ep_1_url: nil,
        cf_domain: nil,
        status: Stream.statuses[:inactive]
      )
      @stream.save!

      StreamStopWorker.perform_async(@stream.id)
    ensure
      if was_running
        @stream.stopped_at = now
        played_time = (@stream.stopped_at - @stream.started_at).to_i

        unless @stream.user.enabled_live_video_free
          Activity.create(
            sender_id: @stream.user_id,
            receiver_id: @stream.user_id,
            message: played_time.to_s,
            assoc_type: 'User',
            assoc_id: @stream.user_id,
            module_type: Activity.module_types[:activity],
            action_type: Activity.action_types[:demand_host_stream],
            alert_type: Activity.alert_types[:both],
            status: Activity.statuses[:read]
          )

          checkpoint(@stream.stopped_at, @stream.watching_viewers, @stream.total_viewers)
          Payment.pay_stream(stream: @stream)
        else
          Activity.create(
            sender_id: @stream.user_id,
            receiver_id: @stream.user_id,
            message: played_time.to_s,
            assoc_type: 'User',
            assoc_id: @stream.user_id,
            module_type: Activity.module_types[:activity],
            action_type: Activity.action_types[:free_host_stream],
            alert_type: Activity.alert_types[:both],
            status: Activity.statuses[:read]
          )

          @stream.user.update_attributes(
            free_streamed_time: @stream.user.free_streamed_time + played_time,
            stream_rolled_time: 0,
            stream_rolled_cost: 0
          )
        end
      end
    end

    return result
  end
end
