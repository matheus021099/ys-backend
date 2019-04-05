class FileUploader < ApplicationUploader
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
end
