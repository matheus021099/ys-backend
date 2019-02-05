class SamplingSerializer < ActiveModel::Serializer
  attributes :id, :sampling_user_id, :sampling_album_id, :sampling_track_id,
    :sample_user_id, :sample_album_id, :sample_track_id, :position
end
