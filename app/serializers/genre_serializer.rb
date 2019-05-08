class GenreSerializer < ActiveModel::Serializer
  attributes :id, :slug, :name, :region, :color, :sequence
  attribute :users_size
  attribute :children, if: :include_children?

  def users_size
    return 0 unless scope && scope.genre_users
    return scope.genre_users[object.id] || 0 unless object.child_ids && object.child_ids.length > 0
    object.child_ids.inject(0){|total, genre_id| total += (scope.genre_users[genre_id] || 0) }
  end

  def children
    # child_genres = Genre.where(id: object.child_ids)
    child_genres = object.children
    ActiveModelSerializers::SerializableResource.new(
      child_genres,
      each_serializer: GenreSerializer,
      scope: scope,
      include_children: false
    )
  end

  def include_children?
    instance_options[:include_children] || false
  end
end