class StreamRemainingCounter
  include Sidekiq::Worker

  sidekiq_options queue: 'high', unique: :until_and_while_executing

  def perform()
    Stream.where("status = ? AND started_at + valid_period * interval '1 second' < ?", Stream.statuses[:running], Time.now).each do |stream|
      stream.remove
    end
  end
end
