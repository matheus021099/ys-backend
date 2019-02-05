class StreamStartedChecker
  include Sidekiq::Worker

  @@medialive = nil

  sidekiq_options retry: 15, queue: :critical, unique: :while_executing

  sidekiq_retry_in do |count|
    20
  end

  sidekiq_retries_exhausted do |msg, ex|
    Sidekiq.logger.warn "Failed #{msg['class']} with #{msg['args']}: #{msg['error_message']}"
    stream = Stream.find_by(id: msg['args'][0])
    stream.remove if stream.present?
  end

  def perform(stream_id)
    # Do something
    @@medialive ||= Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
    stream = Stream.find_by(id: stream_id)
    if stream.present? && stream.status == Stream.statuses[:starting]
      begin
        resp = @@medialive.describe_channel({
          channel_id: stream.ml_channel_id,
        })
        if resp && resp.state == 'RUNNING'
          stream.run
        else
          raise "Channel not running yet. Try again..."
        end
      rescue => e
        raise e.message
      end
    end
  end
end
