class VideoCoverUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_whitelist
    %w(jpg jpeg gif png)
  end

  process :resize_to_fill => [640, 360]

  # Create different versions of your uploaded files:
  version :large do
    process :resize_to_fill => [1280, 720]
  end

  version :thumb do
    process :resize_to_fill => [320, 180]
  end
end
