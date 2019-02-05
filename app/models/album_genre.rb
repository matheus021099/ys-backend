class AlbumGenre < ApplicationRecord
  belongs_to :album
  belongs_to :genre

  validates :genre, presence: true
end
