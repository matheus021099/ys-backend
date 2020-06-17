require 'net/http'
require 'uri'

class StreamSignalChecker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, unique: :until_and_while_executing

  def perform
    notify
  end

  def notify
    Stream.where(status: Stream.statuses[:running], notified: false).each do |stream|
      uri = URI::parse(stream.mp_channel_1_ep_1_url)
      request = Net::HTTP::Get.new(uri)
      request['Pragma']           = 'no-cache'
      request['Accept-Language']  = 'en-US,en;q=0.8,ru;q=0.6'
      request['Accept']           = 'application/json, text/javascript, */*; q=0.01'
      request['X-Requested-With'] = 'XMLHttpRequest'
      request['Cookie']           = ';'
      request['Connection']       = 'keep-alive'
      request['Cache-Control']    = 'no-cache'
      req_options = {
        use_ssl: uri.scheme == 'https',
      }
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.open_timeout = 1000
        http.request(request)
      end
      stream.notify if response.code_type == Net::HTTPOK
    end
  end
end
