class AvatarUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_whitelist
    %w(jpg jpeg gif png)
  end

  process :resize_to_fill => [400, 400]

  # Create different versions of your uploaded files:
  version :thumb do
    process :resize_to_fill => [100, 100]
  end
end
