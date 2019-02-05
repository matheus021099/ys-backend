require 'json'
require 'audio_trimmer'
require 'openssl'
require 'base64'
require 'net/http/post/multipart'

class Util::Audio
  class << self
    def clip(input_file_path)
      file_name = File.basename(input_file_path)
      output_file_dir = Rails.root.join('public', 'uploads', 'tmp', 'clip')
      output_file_path = output_file_dir.join(file_name)
      FileUtils.mkdir_p(output_file_dir) unless File.exists?(output_file_dir)

      trimmer = AudioTrimmer.new input: input_file_path
      trimmer.trim start: 30, finish: 45, output: output_file_path

      output_file_path
    end

    def add_to_acr(file_path: '',  track_id: '', track_name: '', artist_name: '')
      requrl = "https://api.acrcloud.com/v1/audios"
      access_key = ENV['ACRCLOUD_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_ACCESS_SECRET']
      bucket_name = ENV['ACRCLOUD_2_BUCKET']

      data_type = "audio"
      # data_type = "fingerprint"

      http_method = "POST"
      http_uri = "/v1/audios"
      signature_version = "1"
      timestamp = Time.now.utc().to_i.to_s

      string_to_sign = http_method+"\n"+http_uri+"\n"+access_key+"\n"+signature_version+"\n"+timestamp

      digest = OpenSSL::Digest.new('sha1')
      signature = Base64.encode64(OpenSSL::HMAC.digest(digest, access_secret, string_to_sign)).gsub("\n",'')

      # audio_id = track_id.delete('-').to_i(16)
      audio_id = track_id

      result = nil
      url = URI.parse(requrl)
      File.open(file_path) do |file|
        req = Net::HTTP::Post::Multipart.new url.path,
          "audio_file" => UploadIO.new(file, "audio/mp3", file_path),
          "title" => "song-#{track_id}",
          "audio_id" => audio_id,
          "bucket_name" => bucket_name,
          "data_type" => data_type,
          "custom_key[0]" => "name",
          "custom_value[0]" => track_name,
          "custom_key[1]" => "artist",
          "custom_value[1]" => artist_name
        req.add_field("access-key", access_key)
        req.add_field("signature-version", signature_version)
        req.add_field("signature", signature)
        req.add_field("timestamp", timestamp)
        res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
          http.request(req)
        end
        result = res.body
        result = JSON.parse(result) rescue nil
        # p result
      end
      result
    end

    def update_in_acr(acr_id: '', track_name: '', artist_name: '')
      requrl = "https://api.acrcloud.com/v1/audios/#{acr_id}"
      access_key = ENV['ACRCLOUD_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_ACCESS_SECRET']

      http_method = "POST"
      http_uri = "/v1/audios/#{acr_id}"
      signature_version = "1"
      timestamp = Time.now.utc().to_i.to_s

      string_to_sign = http_method+"\n"+http_uri+"\n"+access_key+"\n"+signature_version+"\n"+timestamp

      digest = OpenSSL::Digest.new('sha1')
      signature = Base64.encode64(OpenSSL::HMAC.digest(digest, access_secret, string_to_sign)).gsub("\n",'')

      result = nil
      url = URI.parse(requrl)
      req = Net::HTTP::Post::Multipart.new url.path,
        "custom_key[0]" => "name",
        "custom_value[0]" => track_name,
        "custom_key[1]" => "artist",
        "custom_value[1]" => artist_name
      req.add_field("access-key", access_key)
      req.add_field("signature-version", signature_version)
      req.add_field("signature", signature)
      req.add_field("timestamp", timestamp)
      res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        http.request(req)
      end
      result = res.body
      result = JSON.parse(result) rescue nil
      # p result
      result
    end

    def remove_from_acr(acr_id)
      requrl = "https://api.acrcloud.com/v1/audios/#{acr_id}"
      access_key = ENV['ACRCLOUD_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_ACCESS_SECRET']

      http_method = "DELETE"
      http_uri = "/v1/audios/#{acr_id}"
      signature_version = "1"
      timestamp = Time.now.utc().to_i.to_s

      string_to_sign = http_method+"\n"+http_uri+"\n"+access_key+"\n"+signature_version+"\n"+timestamp

      digest = OpenSSL::Digest.new('sha1')
      signature = Base64.encode64(OpenSSL::HMAC.digest(digest, access_secret, string_to_sign)).gsub("\n",'')

      url = URI.parse(requrl)
      req = Net::HTTP::Delete.new url.path
      req.add_field("access-key", access_key)
      req.add_field("signature-version", signature_version)
      req.add_field("signature", signature)
      req.add_field("timestamp", timestamp)
      res = Net::HTTP.start(url.host, url.port, use_ssl: true) do |http|
        http.request(req)
      end
      result = res.body
      result = JSON.parse(result) rescue nil
      # p result
      result
    end

    def check_local_fingerprint(file_path)
      requrl = "http://#{ENV['ACRCLOUD_2_HOST']}/v1/identify"
      access_key = ENV['ACRCLOUD_2_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_2_ACCESS_SECRET']

      check_fingerprint(file_path: file_path, requrl: requrl, access_key: access_key, access_secret: access_secret)
    end

    def check_global_fingerprint(file_path)
      requrl = "http://#{ENV['ACRCLOUD_1_HOST']}/v1/identify"
      access_key = ENV['ACRCLOUD_1_ACCESS_KEY']
      access_secret = ENV['ACRCLOUD_1_ACCESS_SECRET']

      check_fingerprint(file_path: file_path, requrl: requrl, access_key: access_key, access_secret: access_secret)
    end

    def check_fingerprint(file_path: '', requrl: '', access_key: '', access_secret: '')
      http_method = "POST"
      http_uri = "/v1/identify"
      data_type = "audio"
      # data_type = "fingerprint"
      signature_version = "1"
      timestamp = Time.now.utc().to_i.to_s

      string_to_sign = http_method+"\n"+http_uri+"\n"+access_key+"\n"+data_type+"\n"+signature_version+"\n"+timestamp

      digest = OpenSSL::Digest.new('sha1')
      signature = Base64.encode64(OpenSSL::HMAC.digest(digest, access_secret, string_to_sign))

      sample_bytes = File.size(file_path)

      result = nil
      url = URI.parse(requrl)
      File.open(file_path) do |file|
        req = Net::HTTP::Post::Multipart.new url.path,
          "sample" => UploadIO.new(file, "audio/mp3", file_path),
          "access_key" => access_key,
          "data_type" => data_type,
          "signature_version" => signature_version,
          "signature" => signature,
          "sample_bytes" => sample_bytes,
          "timestamp" => timestamp
        res = Net::HTTP.start(url.host, url.port) do |http|
          http.request(req)
        end
        result = res.body
        result = JSON.parse(result) rescue nil
        # p result
      end
      result
    end
  end
end
