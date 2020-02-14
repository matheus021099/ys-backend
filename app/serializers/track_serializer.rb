class TrackSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :audio, :status, :downloaded, :played, :audio_download_url
  attribute :user, if: :include_user?
  attribute :album

  def user
    UserSerializer1.new(
      object.user,
      scope: scope,
      include_is_following: instance_options[:include_user_is_following]
    )
  end

  def album
    object.album.as_json(
      only: [ :id, :slug, :name, :cover, :album_type ]
    )
  end

  def include_user?
    instance_options[:include_user] || false
  end
end
