require 'clockwork'
require_relative './boot'
require_relative './environment'

module Clockwork
  handler do |job, time|
    puts "Running #{job}, at #{time}"
  end

  configure do |config|
    config[:tz] = Time.zone
  end

  # every(10.seconds, 'stream_signal_checker') {
  #   StreamSignalChecker.perform_async
  #   # StreamRemainingCounter.perform_async
  # }
  every(1.minute, 'stream_checker') {
    StreamChecker.perform_async
    AlbumChecker.perform_async
  }
  every(1.hour, 'post_checker') {
    PostChecker.perform_async
    InvitationChecker.perform_async
  }
  every(12.hours, 'message_checker') {
    MessageChecker.perform_async
    RepostPriceExpireChecker.perform_async
  }
end
