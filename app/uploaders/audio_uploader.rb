class AudioUploader < ApplicationUploader
  include CarrierWave::Uploader

  def fog_public
    false
  end

  def fog_authenticated_url_expiration
    86400
  end

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # def will_include_content_type
  #   true
  # end

  # default_content_type  'audio/mpeg'
  # allowed_content_types %w(audio/mpeg)
end