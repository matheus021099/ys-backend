require 'open-uri'
class WebController < ApplicationController
  include ActionController::Live # required for streaming
  include ZipTricks::RailsStreaming

  # include ActionController::Streaming
  # include Zipline

  skip_before_action :authenticate_token!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def stripe_connect_callback
    puts "\n\n stripe_connect_callback"
    p request
    # p request.env['omniauth.auth']
    puts "\n\n\n"

    if user_signed_in?
      user.provider = request.env['omniauth.auth'].provider
      user.account_id = request.env['omniauth.auth'].uid
      user.account_type = 'standalone'
      user.access_code = request.env['omniauth.auth'].credentials.token
      user.publishable_key = request.env['omniauth.auth'].info.stripe_publishable_key
      user.save(validate: false)
    end
  end

  def twitter_callback
    skip_authorization

    auth = request.env['omniauth.auth']
    puts "\n\n twitter_callback"
    p auth
    p request
    put "\n\n\n"
  end

  def mux_callback
    puts "\n\n mux_callback"
    p request
    puts "\n\n\n"

    type = request["type"]
    case type
      when 'video.live_stream.active'
        channel_id = request["data"]["id"]
        stream = Stream.find_by(ml_channel_id: channel_id)
        if stream && !(stream.inactive? || stream.deleted?)
          stream.run
          stream.notify
        end
      when 'video.live_stream.idle'
        channel_id = request["data"]["id"]
        stream = Stream.find_by(ml_channel_id: channel_id)
        if stream
          stream.remove
        end
    end
  end

  def download_as_zip
    skip_authorization

    product = ShopProduct.find(params[:album_id])
    files = product.covers.map.with_index{|c, i| next if c.cover.blank? ; [c.cover.url, "#{"%03d" % i}-cover.jpg", c.cover.size ]}.compact
    album = Album.find('96D7B94D-B29D-4B77-B64A-60F311AF986E')
    album.generate_zip(files)
    album.reload
    # redirect_to album.zip.url
    data = open(album.zip.url)
    send_data data.read, filename: "#{album.name.tr(" ", "_")}.zip", type: "application/zip", disposition: 'inline', stream: 'true', buffer_size: '4096'

    # filename = "#{product.name.gsub '"', '\"'}.zip"
    # headers['Content-Disposition'] = "attachment; filename=\"#{filename}\""
    # headers['Content-Type'] = Mime::Type.lookup_by_extension('zip').to_s
    # response.sending_file = true
    # response.cache_control[:public] ||= false
    # zip_tricks_stream do |zip|
    #   files.each do |url, path, size|
    #     puts "\n\n+++++ #{Time.now} - #{path}"
    #     zip.write_stored_file(path) do |writer_for_file|
    #       c = Curl::Easy.new(url) do |curl|
    #         curl.on_body do |data|
    #           writer_for_file << data
    #           puts data.bytesize
    #           data.bytesize
    #         end
    #       end
    #       puts "downloading"
    #       c.perform
    #       puts "performing"
    #     end
    #   end
    # end

    # dir = Rails.root.join('public', 'uploads', 'albums')
    # Dir.mkdir(dir) unless Dir.exist?(dir)
    # io = File.open(dir.join("#{params[:album_id]}.zip"), 'wb')
    # ZipTricks::Streamer.open(io) do |zip|
    #   files.each do |url, path, size|
    #     puts "\n\n+++++ #{Time.now} - #{path}"
    #     # zip.write_stored_file(path) do |writer_for_file|
    #     #   c = Curl::Easy.new(url) do |curl|
    #     #     curl.on_body do |data|
    #     #       writer_for_file << data
    #     #       puts data.bytesize
    #     #       data.bytesize
    #     #     end
    #     #   end
    #     #   puts "downloading"
    #     #   c.perform
    #     #   puts "performing"
    #     # end
    #     # f = open(url)
    #     # crc32 = ZipTricks::StreamCRC32.from_io(f)
    #     # zip.add_stored_entry(filename: path, size: f.size, crc32: crc32)
    #     # io.sendfile(f)
    #     # zip.simulate_write(f.size)
    #   end
    # end
    # send_data(io, :type => 'application/zip', :filename => filename)
  end

  # def download_as_zip
  #   skip_authorization
  #   # album = Album.find_by_slug(params[:album_id]) || Album.find(params[:album_id])
  #   # files = album.tracks.map{ |track| [track.audio.url, "#{track.name.parameterize}.mp3"] }
  #   product = ShopProduct.first
  #   files = product.covers.map.with_index{ |c,i| next if c.cover.blank? ; [c.cover.url, "cover-#{i}.jpg" ] }.compact
  #   puts '+++++'
  #   puts files
  #   file_mappings = files
  #     .lazy  # Lazy allows us to begin sending the download immediately instead of waiting to download everything
  #     .map { |url, path| [open(url), path] }
  #   zipline(file_mappings, "#{product.name.parameterize}.zip")
  # end
end
