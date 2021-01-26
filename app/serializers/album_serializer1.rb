# used in search_controller
class AlbumSerializer1 < Panko::Serializer
  attributes :id, :slug, :name, :cover, :album_type, :recommended, :collaborators_count

  attributes :user, :genres, :tracks
  attributes :collaborators

  def cover
    {
      url: object.cover.url
    }
  end

  def user
    ActiveModel::Serializer::UserSerializer1.new(
      object.user,
      scope: scope,
      include_is_following: true
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
