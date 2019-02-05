class AlbumTrack < ApplicationRecord
  self.table_name = "albums_tracks"

  belongs_to :album
  belongs_to :track

  # validates :album, presence: true
  validates :track, presence: true
end
