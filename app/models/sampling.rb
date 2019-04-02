class Sampling < ApplicationRecord
  belongs_to :sampling_user, class_name: 'User'
  belongs_to :sampling_album, class_name: 'Album'
  belongs_to :sampling_track, class_name: 'Track'

  belongs_to :sample_user, class_name: 'User'
  belongs_to :sample_album, class_name: 'Album'
  belongs_to :sample_track, class_name: 'Track'
end
