class StreamChecker
  include Sidekiq::Worker

  sidekiq_options queue: :high, unique: :until_and_while_executing

  def perform
    checkpoint
    # remaining_time
    # abnormal_delete
  end

  def checkpoint
    Stream.where(status: Stream.statuses[:running]).each do |stream|
      if stream.checkpoint == 0
        stream.remove
      end
    end
  end

  def remaining_time
    # Stream.where("status = ? AND started_at + valid_period * interval '1 second' < ?", Stream.statuses[:running], 10.minutes.ago).each do |stream|
    #   stream.remove
    # end

    Stream.where(
      "status = ? AND remaining_seconds >= ? AND checkpoint_at + remaining_seconds * interval '1 second' < ?",
      Stream.statuses[:running],
      0,
      Time.now
    ).each do |stream|
      stream.remove
    end
  end

  def abnormal_delete
    Stream.where("status = ? AND mp_channel_1_id IS NOT NULL", Stream.statuses[:inactive]).each do |stream|
      stream.remove
    end
  end
end
