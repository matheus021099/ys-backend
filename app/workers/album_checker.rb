class AlbumChecker
  include Sidekiq::Worker

  sidekiq_options queue: 'high', unique: :until_and_while_executing

  def perform
    no_tracks
    not_belongs_to_album
  end

  # check albums/playlists which have no tracks
  def no_tracks
    Album.joins("LEFT JOIN albums_tracks at ON albums.id = at.album_id").where(
      "at.track_id IS NULL"
    ).each do |album|
      if album.playlist?
        album.destory
      else
        album.make_private
      end
    end
  end

  # check tracks which belongs to any album
  def not_belongs_to_album
    Track.joins("LEFT JOIN albums_tracks at ON tracks.id = at.track_id").where(
      "at.album_id IS NULL AND created_at < ?",
      3.days.ago
    ).destroy_all
  end
end
