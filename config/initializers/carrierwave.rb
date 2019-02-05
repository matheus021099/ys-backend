require 'carrierwave/storage/fog'
CarrierWave.configure do |config|
  # if Rails.env.production?
    config.storage = :fog
    config.fog_provider = 'fog/aws'
    config.fog_credentials = {
      :provider               => 'AWS',
      :aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
      :aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
      :region                 => ENV['AWS_S3_REGION'],
    }
    config.asset_host = ENV['AWS_CDN_HOST']
    config.fog_directory = ENV['AWS_S3_BUCKET']
    config.fog_public = true
    # config.fog_public = false
    # config.fog_attributes = {'Cache-Control'=>"public, max-age=#{1.day.to_i}"}
    # config.fog_authenticated_url_expiration = 86400
  # else
  #   config.storage = :file
  # end
end