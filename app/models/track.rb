class Track < ApplicationRecord
  # enum status: [ :inactive, :active ]
  enum status: {
    inactive: 'inactive',
    active: 'active'
  }

  mount_uploader :audio, AudioUploader
  mount_uploader :clip, AudioUploader

  validate :audio_size_validation, :if => "audio?"
  def audio_size_validation
    errors[:audio] << "should be less than 250MB" if audio.size > 250.megabytes
  end

  belongs_to :user

  # default
  after_initialize :set_default_values
  def set_default_values
    self.status ||= Track.statuses[:active]
  end

  # add track to acrcloud
  # after_create :add_to_acr
  # def add_to_acr
  # end

  before_destroy :do_before_destroy
  def do_before_destroy
    Activity.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    AlbumTrack.where(track_id: self.id).delete_all

    Sampling.where('sample_track_id = ? OR sampling_track_id = ?', self.id, self.id).delete_all
  end

  # remove track from acrcloud
  # after_destroy :remove_from_acr
  # def remove_from_acr
  #   Util::Audio.remove_from_acr(self.acr_id) unless self.acr_id.blank?
  # end

  # slug
  extend FriendlyId
  friendly_id :slug_candidates, use: [:slugged, :finders]
  def slug_candidates
    [ :name ]
  end

  def audio_download_url
    track_name = self.name[-4] == '.' || self.name[-5] == '.' ? self.name : self.name + '.mp3'
    # url_options = {
    #   expires_in: 60.minutes,
    #   use_ssl: false,
    #   response_content_disposition: "attachment; filename=\"#{track_name}\""
    # }
    self.audio.url(query: {:"response-content-disposition" => "attachment; filename=\"#{track_name}\""})
  end

  # def remove
  #   remove track from albums
  #   album_ids = AlbumTrack.where(track_id: self.id).pluck(:album_id)
  #   AlbumTrack.where(track_id: self.id).delete_all
  #   Album.includes(:album_tracks, :tracks).playlists.where(id: album_ids).each do |album|
  #     album.destroy if album.album_tracks.size == 0
  #   end
  #   self.destroy
  # end

  def download(downloader, page_track = nil)
    return true if downloader.id == self.user_id

    activity = Activity.insert(
      sender_id: downloader.id,
      receiver_id: downloader.id,
      message: 'downloaded a track',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:log],
      action_type: Activity.action_types[:download],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:read]
    )

    Activity.insert(
      sender_id: downloader.id,
      receiver_id: self.user.id,
      message: 'downloaded your track',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:log],
      action_type: Activity.action_types[:download],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:read]
    )

    self.update_attributes(downloaded: self.downloaded + 1) if activity

    true
  end

  def play(player)
    return true if player.id == self.user_id

    activity = Activity.insert(
      sender_id: player.id,
      receiver_id: player.id,
      message: 'played a track',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:log],
      action_type: Activity.action_types[:play],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    Activity.insert(
      sender_id: player.id,
      receiver_id: self.user_id,
      message: 'played your track',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:log],
      action_type: Activity.action_types[:play],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    self.update_attributes(played: self.played + 1) if activity

    true
  end
end
