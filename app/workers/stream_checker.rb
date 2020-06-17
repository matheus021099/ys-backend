class StreamChecker
  include Sidekiq::Worker

  sidekiq_options queue: :high, unique: :until_and_while_executing

  def perform
    remaining_time
    abnormal_delete
  end

  def remaining_time
    Stream.where("status = ? AND started_at + valid_period * interval '1 second' < ?", Stream.statuses[:running], 10.minutes.ago).each do |stream|
      stream.remove
    end
  end

  def abnormal_delete
    Stream.where("status = ? AND mp_channel_1_id IS NOT NULL", Stream.statuses[:inactive]).each do |stream|
      stream.remove
    end
  end
end
