class SamplingSerializer < ActiveModel::Serializer
  attributes :id,
    :sampling_user_id, :sampling_album_id, :sampling_track_id, :position,
    :sample_user_id, :sample_album_id, :sample_track_id,
    :sampling_track,
    :sample_user, :sample_album, :sample_track

  def sampling_track
    object.sampling_track.as_json(only: [:id, :slug, :name])
  end

  def sample_user
    object.sample_user.as_json(only: [:id, :slug, :display_name, :avatar])
  end

  def sample_album
    object.sample_album.as_json(only: [:id, :slug, :name, :cover])
  end

  def sample_track
    object.sample_track.as_json(only: [:id, :slug, :name])
  end
end
