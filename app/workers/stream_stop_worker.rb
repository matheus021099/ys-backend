class StreamStopWorker
  include Sidekiq::Worker

  @@medialive = nil

  sidekiq_options retry: 10, queue: :default, unique: :until_and_while_executing

  sidekiq_retry_in do |count|
    100
  end

  def perform(stream_id)
    # Do something
    @@medialive ||= Aws::MediaLive::Client.new(region: ENV['AWS_REGION'])
    stream = Stream.find_by(id: stream_id)
    if stream.present? && stream.status == Stream.statuses[:inactive]
      unless stream.ml_channel_id.blank?
        begin
          resp = @@medialive.describe_channel({
            channel_id: stream.ml_channel_id,
          })
          if resp && resp.state == 'DELETED'
            @@medialive.delete_input({
              input_id: stream.ml_input_id
            })
            # stream.destroy
            stream.deleted!
          else
            raise "Channel not deleted yet. Try again..."
          end
        rescue => e
          raise e.message
        end
      else
        # stream.destroy
        stream.deleted!
      end
    end
  end
end
