class Services::Mux
  include HTTParty

  base_uri 'https://api.mux.com/video'

  MUX_TOKEN_ID = ENV['MUX_TOKEN_ID']
  MUX_TOKEN_SECRET = ENV['MUX_TOKEN_SECRET']

  def initialize
    @auth = {username: MUX_TOKEN_ID, password: MUX_TOKEN_SECRET}
  end

  def createStream
    body = {
      "playback_policy": ["public"],
      "new_asset_settings": {
        "playback_policy": ["public"]
      }
    }

    options = {
      body: body,
      basic_auth: @auth
    }

    self.class.post('/v1/live-streams', options)
  end

  def getStream(stream_id)
    options = {
      basic_auth: @auth
    }
    self.class.get(`/v1/live-streams/#{stream_id}`, options)
  end

  def deleteStream(stream_id)
    options = {
      basic_auth: @auth
    }
    self.class.delete(`/v1/live-streams/#{stream_id}`, options)
  end
end
