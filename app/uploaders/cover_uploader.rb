class CoverUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_whitelist
    %w(jpg jpeg gif png)
  end

  process :resize_to_fill => [600, 600]

  # Create different versions of your uploaded files:
  version :large do
    process :resize_to_fill => [1200, 1200]
  end

  version :thumb do
    process :resize_to_fill => [200, 200]
  end
end
