# used in search_controller
class AlbumSerializer1 < ActiveModel::Serializer
  attributes :id, :slug, :name, :description, :cover, :album_type, :recommended, :collaborators_count

  attribute :user
  attributes :genres, :tracks
  attributes :collaborators, :can_edit_collaborators

  def user
    ActiveModel::Serializer::UserSerializer.new(
      object.user,
      scope: scope,
      include_recent_reposted: instance_options[:include_user_recent],
      recent_count: 4
    )
  end

  def genres
    if object.genre_objects
      ActiveModelSerializers::SerializableResource.new(
        object.genre_objects,
        each_serializer: GenreSerializer,
        scope: scope
      )
    end
  end

  def tracks
    object.album_tracks.map{ |at|
      next unless at.present? && at.track.present?
      result = TrackSerializer.new(
        at.track,
        scope: scope,
        include_user: object.playlist?,
        include_user_is_following: true
      ).as_json
      result['position'] = at.position
      result
    }.compact
  end

  def collaborators
    user_albums = object.user_albums.where(users_albums: { user_type: UserAlbum.user_types[:collaborator] })
    ActiveModelSerializers::SerializableResource.new(
      user_albums,
      each_serializer: UserAlbumSerializer,
      scope: scope,
      include_user: true
    )
  end
end
