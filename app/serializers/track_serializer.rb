class TrackSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :audio, :status, :downloaded, :played
  attribute :audio_download_url
  belongs_to :user, if: :include_user?

  def include_user?
    instance_options[:include_user] || false
  end
end
