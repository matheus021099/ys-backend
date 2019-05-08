class UserAlbumSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :album_id, :user_type, :user_role, :status

  attribute :user, if: :include_user?
  attribute :album, if: :include_album?

  def user
    UserSerializer1.new(
      object.user,
      scope: scope,
      include_is_following: instance_options[:include_user_is_following]
    )
  end

  def include_user?
    instance_options[:include_user] || false
  end

  def include_album?
    instance_options[:include_album] || false
  end
end