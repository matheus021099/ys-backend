class UserAlbumSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :album_id, :user_type, :user_role, :status

  belongs_to :user, if: :include_user?
  belongs_to :album, if: :include_album?

  def include_user?
    instance_options[:include_user] || false
  end

  def include_album?
    instance_options[:include_album] || false
  end
end