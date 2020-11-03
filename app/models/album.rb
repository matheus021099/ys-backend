class Album < ApplicationRecord
  # include AuthenticatorConcern

  # enum status: [:draft, :privated, :published, :pending, :collaborated, :deleted]
  enum status: {
    draft: 'draft',
    privated: 'privated',
    published: 'published',
    pending: 'pending',
    collaborated: 'collaborated',
    deleted: 'deleted'
  }

  enum album_type: [:album, :playlist]

  mount_uploader :cover, CoverUploader
  mount_uploader :zip, FileUploader

  paginates_per 25

  searchkick word_start: %i[id name slug description owner_username owner_display_name],
    searchable: %i[id name slug description owner_username owner_display_name]

  def search_data
    attributes.merge(search_custom_fields)
  end

  def search_custom_fields
    {
      owner_username: self.user.username,
      owner_display_name: self.user.display_name
    }
  end

  validates :name, presence: true, on: :create

  # validate :cover_size_validation, :if => "cover?"
  # def cover_size_validation
  #   puts "\n\n"
  #   p cover.large.size
  #   p 1.megabytes
  #   puts "\n\n\n"
  #   errors[:cover] << "should be less than 1MB" if cover.large.size > 1.megabytes
  # end

  # default
  after_initialize :set_default_values
  def set_default_values
    self.status ||= Album.statuses[:draft]
    self.album_type ||= Album.album_types[:album]
    self.recommended ||= false
    self.released ||= false
  end

  before_destroy :do_before_destroy
  def do_before_destroy
    Activity.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Feed.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Comment.where(
      commentable_type: self.class.name,
      commentable_id: self.id
    ).delete_all

    Stream.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).update_all(
      assoc_type: nil,
      assoc_id: nil
    )

    Post.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).update_all(
      assoc_type: nil,
      assoc_id: nil
    )

    # remove samplings
    Sampling.where(
      'sample_album_id = ? OR sampling_album_id = ?',
      self.id,
      self.id
    ).delete_all

    # remove attachment for messages
    attachment_ids = Attachment.where(
      attachable_type: self.class.name,
      attachable_id: self.id,
    ).pluck(:id)

    Payment.where(attachment_id: attachment_ids).delete_all

    Attachment.where(id: attachment_ids).each do |attachment|
      attachment.message.destroy if attachment.message.present?
      attachment.delete
    end

    # notify collaborators album has been deleted
    user_albums = self.user_albums.includes(:user).where(users_albums: {
      user_type: UserAlbum.user_types[:collaborator],
      # status: UserAlbum.statuses[:accepted]
    })
    message_body = "#{self.user.display_name} has deleted an album: <b>#{self.name}</b>"
    user_albums.each do |ua|
      collaborator = ua.user
      Util::Message.send(self.user, collaborator, message_body)
    end
  end

  # slug
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged
  def slug_candidates
    [ :name ]
  end

  belongs_to :user
  has_many :user_albums, dependent: :destroy
  # has_many :labels, -> { where user_albums: { user_type: UserAlbum.user_types[:label], status: UserAlbum.statuses[:accepted] } }, through: :user_albums
  # has_many :collaborators, -> { where user_albums: { user_type: UserAlbum.user_types[:collaborator] } }, through: :user_albums
  has_many :album_tracks, -> { order(position: :asc) }
  has_many :tracks, through: :album_tracks, dependent: :destroy#, after_remove: :async_generate_zip, after_add: :async_generate_zip
  # has_many :album_genres
  # has_many :genres, through: :album_genres
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :activities, as: :assoc, dependent: :destroy
  has_many :feeds, as: :assoc, dependent: :destroy
  has_many :samplings, foreign_key: 'sampling_album_id', class_name: 'Sampling'

  accepts_nested_attributes_for :album_tracks#, :album_genres

  acts_as_taggable_on :genres
  acts_as_taggable_on :products

  scope :most_recent, -> {order('created_at desc')}
  scope :most_downloaded, -> {order('downloaded desc')}
  # scope :most_downloaded, -> { order('downloaded').joins("LEFT OUTER JOIN feeds ON feeds.assoc_type='Album' AND album.id = feeds.assoc_id AND feeds.feed_type = 'download'").group('feeds.id') }

  scope :published, -> { where status: Album.statuses[:published] }
  scope :playlists, -> { where album_type: Album.album_types[:playlist] }
  scope :not_playlists, -> { where.not album_type: Album.album_types[:playlist] }

  # def remove
  #   album = self
  #   ActiveRecord::Base.transaction do
  #     user_albums = album.user_albums.includes(:user).where(users_albums: {
  #       user_type: UserAlbum.user_types[:collaborator],
  #       status: UserAlbum.statuses[:accepted]
  #     })
  #     message_body = "#{album.user.display_name} has deleted an album: <b>#{album.name}</b>"
  #     user_albums.each do |ua|
  #       collaborator = ua.user
  #       Util::Message.send(album.user, collaborator, message_body)
  #     end
  #     album_id = album.id
  #     track_ids = Track.where(album_id: album_id).pluck(:id)
  #     Activity.where("assoc_type = 'Album' AND assoc_id = ?", album_id).destroy_all
  #     Feed.where("assoc_type = 'Album' AND assoc_id = ?", album_id).destroy_all
  #     Comment.where("commentable_type = 'Album' AND commentable_id = ?", album_id).destroy_all
  #     Stream.where("assoc_type = 'Album' AND assoc_id = ?", album_id).update_all(assoc_type: nil, assoc_id: nil)
  #     Post.where("assoc_type = 'Album' AND assoc_id = ?", album_id).update_all(assoc_type: nil, assoc_id: nil)
  #     # UserAlbum.where(album_id: album_id).destroy_all
  #     AlbumTrack.where(track_id: track_ids).destroy_all
  #     Track.where(id: track_ids).destroy_all
  #     Sampling.where("sampling_album_id = ? OR sample_album_id = ?", album_id, album_id).destroy_all
  #     attachment_ids = Attachment.where("attachable_type = 'Album' AND attachable_id = ?", album_id).pluck(:id)
  #     notification_ids = Attachment.where("attachable_type = 'Album' AND attachable_id = ?", album_id).pluck(:mailboxer_notification_id)
  #     Mailboxer::Notification.where(id: notification_ids).destroy_all
  #     Attachment.where(id: attachment_ids).destroy_all
  #     album.destroy
  #   end
  #   true
  # end

  def genre_objects
    # Genre.where(name: self.genre_list)
    Genre.where(id: self.genre_list)
  end

  def product_objects
    ShopProduct.where(id: self.product_list)
  end

  def has_tracks?
    self.tracks.size > 0
  end

  def has_cover?
    not self.cover.blank?
  end

  def ready_release_album?
    self.has_tracks? && self.has_cover?
  end

  def ready_release_playlist?
    self.has_tracks?
  end

  def ready_release?
    (self.playlist? && self.ready_release_playlist?) || (self.album? && self.ready_release_album?)
  end

  def released?
    self.ready_release? && self.released && self.published?
  end

  def has_pending_collaborators?
    UserAlbum.where(
      album_id: self.id,
      user_type: UserAlbum.user_types[:collaborator],
      status: UserAlbum.statuses[:pending]
    ).size > 0
  end

  def can_edit_collaborators
    self.status
    # return false if self.status == Album.statuses[:published] || self.status == Album.statuses[:collaborated]
    return false if self.status == 'published' || self.status == 'collaborated'
    return true if self.collaborators_count == 0
    not has_pending_collaborators?
  end

  def release
    if self.is_only_for_live_stream
      Feed.where(
        assoc_type: self.class.name,
        assoc_id: self.id
      ).delete_all

      Activity.where(
        assoc_type: self.class.name,
        assoc_id: self.id,
      ).delete_all
    end

    return if self.released?
    return if self.collaborators_count != 0 && self.has_pending_collaborators?

    #TODO - wonder difference between released and published
    new_status = self.collaborators_count == 0 ? Album.statuses[:published] : Album.statuses[:collaborated]
    self.update_attributes(
      status: new_status,
      released: true,
      released_at: self.released_at || Time.now.utc
    )

    return if self.is_only_for_live_stream || self.playlist?

    Feed.insert(
      consumer_id: self.user_id,
      publisher_id: self.user_id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:release]
    )

    Activity.create(
      sender_id: self.user_id,
      receiver_id: self.user_id,
      message: 'released an album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:release],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    self.user.followers.each do |follower|
      next if follower.blank?

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: self.user_id,
        assoc_type: self.class.name,
        assoc_id: self.id,
        feed_type: Feed.feed_types[:release]
      )

      # if feed && follower.enable_alert
      #   Activity.create(
      #     sender_id: self.user_id,
      #     receiver_id: follower.id,
      #     message: 'updated your stream',
      #     module_type: Activity.module_types[:stream],
      #     action_type: Activity.action_types[:release],
      #     alert_type: Activity.alert_types[:both],
      #     status: Activity.statuses[:unread]
      #   )
      # end
    end

    true
  end

  def make_public
    self.update_attributes(
      is_only_for_live_stream: false,
      status: Album.statuses[:published]
    )
  end

  def make_private
    Activity.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Feed.where({
      assoc_type: self.class.name,
      assoc_id: self.id
    }).delete_all

    self.update_attributes(
      status: Album.statuses[:privated]
    )
  end

  def make_live_video_only
    Feed.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Activity.where(
      assoc_type: self.class.name,
      assoc_id: self.id,
    ).delete_all

    self.update_attributes(is_only_for_live_stream: false)
  end

  def recommend(actor)
    self.update_attributes(
      recommended_at: Time.now,
      recommended: true
    )

    message_body = "YouSound has recommended your album: <b>#{self.name}</b>"
    Util::Message.send(actor, self.user, message_body)
  end

  def unrecommend
    self.update_attributes(
      recommended_at: nil,
      recommended: false
    )
  end

  def hide(actor)
    return 'You are trying to hide your album' if actor.id == self.user_id

    Feed.where({
      publisher_id: actor.id,
      assoc_type: self.class.name,
      assoc_id: self.id
    }).delete_all

    feed = Feed.insert(
      consumer_id: actor.id,
      publisher_id: actor.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:hide]
    )

    # Activity.create(
    #   sender_id: actor.id,
    #   receiver_id: self.user_id,
    #   message: 'hide your album',
    #   assoc_type: self.class.name,
    #   assoc_id: self.id,
    #   module_type: Activity.module_types[:activity],
    #   action_type: Activity.action_types[:hide],
    #   alert_type: Activity.alert_types[:both],
    #   status: Activity.statuses[:unread]
    # )
    Activity.create(
      sender_id: actor.id,
      receiver_id: actor.id,
      message: 'hide an album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:hide],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    true
  end

  def download(downloader, page_track = nil)
    return true if downloader.id == self.user_id

    # doesn't count the number of download if is_only_for_live_stream
    return true if self.is_only_for_live_stream || self.playlist?

    feed = Feed.insert(
      consumer_id: downloader.id,
      # publisher_id: self.user_id,
      publisher_id: downloader.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:download]
    )

    Activity.create(
      sender_id: downloader.id,
      receiver_id: downloader.id,
      message: 'downloaded an album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:stream],
      action_type: Activity.action_types[:download],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:read]
    )

    # self.update_attributes(downloaded: self.downloaded + 1)

    if feed
      Activity.create(
        sender_id: downloader.id,
        receiver_id: self.user_id,
        message: 'downloaded your album',
        assoc_type: self.class.name,
        assoc_id: self.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:download],
        alert_type: Activity.alert_types[:both],
        page_track: page_track,
        status: Activity.statuses[:unread]
      )
    end

    downloader.followers.each do |follower|
      next if follower.blank?

      # album should not appear in possessor's stream page
      next if follower.id == self.user_id

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: downloader.id,
        assoc_type: self.class.name,
        assoc_id: self.id,
        feed_type: Feed.feed_types[:download]
      )

      # if feed && follower.enable_alert?
      #   Activity.create(
      #     sender_id: downloader.id,
      #     receiver_id: follower.id,
      #     message: 'downloaded an album',
      #     assoc_type: self.class.name,
      #     assoc_id: self.id,
      #     module_type: Activity.module_types[:stream],
      #     action_type: Activity.action_types[:download],
      #     alert_type: Activity.alert_types[:both],
      #     page_track: page_track,
      #     status: Activity.statuses[:unread]
      #   )
      # end
    end

    ### for now, page_track is available for stream
    if page_track.present?
      class_name, instance_id = page_track.split(':').map(&:strip)
      if class_name.present? && instance_id.present?
        begin
          @stream = class_name.constantize.find(instance_id)
          ActionCable.server.broadcast("stream_#{@stream.id}", {downloads_size: 1})
        rescue e
          Rails.logger.info(e.message)
        end
      end
    end

    true
  end

  def play(player)
    return true if player.id == self.user_id

    # feed = Feed.insert(
    #   consumer_id: player.id,
    #   publisher_id: player.id,
    #   assoc_type: self.class.name,
    #   assoc_id: self.id,
    #   feed_type: Feed.feed_types[:play]
    # )

    # played_before = Activity.where(
    #   sender_id: player.id,
    #   receiver_id: self.user_id,
    #   assoc_type: self.class.name,
    #   assoc_id: self.id,
    #   action_type: Activity.action_types[:play]
    # ).size > 0
    # self.update_attributes(played: self.played + 1) unless played_before

    Activity.create(
      sender_id: player.id,
      receiver_id: self.user_id,
      message: 'played your album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:play],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    Activity.create(
      sender_id: player.id,
      receiver_id: player.id,
      message: 'played an album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:play],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    # player.followers.each do |follower|
    #   next if follower.blank?
    #   # album should not appear in possessor's stream page
    #   next if follower.id == self.user_id
    #   feed = Feed.insert(
    #     consumer_id: follower.id,
    #     publisher_id: player.id,
    #     assoc_type: self.class.name,
    #     assoc_id: self.id,
    #     feed_type: Feed.feed_types[:play]
    #   )
    #   if feed && follower.enable_alert?
    #     Activity.create(
    #       sender_id: player.id,
    #       receiver_id: follower.id,
    #       message: 'updated your stream',
    #       assoc_type: self.class.name,
    #       assoc_id: self.id,
    #       module_type: Activity.module_types[:stream],
    #       action_type: Activity.action_types[:play],
    #       alert_type: Activity.alert_types[:both],
    #       status: Activity.statuses[:unread]
    #     )
    #   end
    # end if feed

    true
  end

  def repost(reposter, page_track = nil)
    return 'You are trying to repost your album' if reposter.id == self.user_id

    feed = Feed.insert(
      consumer_id: reposter.id,
      # publisher_id: self.user_id,
      publisher_id: reposter.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:repost]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: self.user_id,
      message: 'reposted your album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:unread]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: reposter.id,
      message: 'reposted an album',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:stream],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:unread]
    )

    # self.update_columns(reposted: self.reposted + 1)

    reposter.followers.each do |follower|
      next if follower.blank?
      # album should not appear in possessor's stream page
      next if follower.id == self.user_id

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: reposter.id,
        assoc_type: self.class.name,
        assoc_id: self.id,
        feed_type: Feed.feed_types[:repost]
      )

      if feed && follower.enable_alert?
        Activity.insert(
          sender_id: reposter.id,
          receiver_id: follower.id,
          message: 'reposted an album',
          assoc_type: self.class.name,
          assoc_id: self.id,
          module_type: Activity.module_types[:stream],
          action_type: Activity.action_types[:repost_by_following],
          alert_type: Activity.alert_types[:both],
          page_track: page_track,
          status: Activity.statuses[:unread]
        )
      end
    end

    message_body = "#{reposter.display_name} reposted [#{self.name}]"
    PushNotificationWorker.perform_async(
      self.user.devices.where(enabled: true).pluck(:token),
      FCMService::push_notification_types[:album_reposted],
      message_body,
      AlbumSerializer1.new(scope: OpenStruct.new(current_user: reposter)).serialize(self).as_json
    )

    true
  end

  def unrepost(unreposter)
    return 'You are trying to un-repost your album' if unreposter.id == self.user_id

    Activity.where({
      sender_id: unreposter.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      action_type: Activity.action_types[:repost]
    }).delete_all

    Feed.where({
      publisher_id: unreposter.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_types: Feed.feed_types[:repost]
    }).delete_all

    true
  end

  def zip_download_url
    album_zip_name = self.name + '.zip'
    self.zip.url(query: {:"response-content-disposition" => "attachment; filename=\"#{album_zip_name}\""})
  end

  def async_generate_zip
    job = ZipUploadJob.new(self.id)
    Delayed::Job.enqueue(job)
  end

  def generate_zip
    # return unless album.released?

    files = self.tracks.map.with_index do |track, i|
      next unless track.audio?
      # [track.audio.url, "#{"%03d" % i}-#{track.name}"]
      # filename = track.name.tr(' ', '_')
      ext = track.audio.file.extension.downcase
      filename = track.name.downcase.end_with?(".#{ext}") ? track.name : "#{track.name}.#{ext}"
      [track.audio.url, filename]
    end.compact

    latest_update_time = self.tracks.maximum('updated_at').utc
    zip_time = self.zip? && self.zipped_at ? self.zipped_at : (latest_update_time - 1.day)
    # zip_time = self.zip? ? url_mtime(self.zip.url).utc : (latest_update_time - 1.day)
    # puts "\n\n"
    # p files
    # p zip_time, latest_update_time, zip_time > latest_update_time
    # puts "\n\n\n"

    return self.zip_download_url if zip_time > latest_update_time

    dir = Rails.root.join('public', 'uploads', 'albums')
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    file_path = dir.join("#{self.id}.zip")
    out = File.open(file_path, 'wb')
    ZipTricks::Streamer.open(out) do |zip|
      files.each do |url, path|
        puts "#{path} - #{url}"
        zip.write_stored_file(path) do |writer_for_file|
          c = Curl::Easy.new(url) do |curl|
            curl.on_body do |data|
              writer_for_file << data
              puts data.bytesize
              data.bytesize
            end
          end
          c.perform
        end
      end
    end

    self.update_attributes(zip: out, zipped_at: Time.now)
    out.close
    File.delete(file_path)

    return self.zip_download_url
  end

  # def url_mtime(url)
  #   Net::HTTP.start(URI(url).host) do |http|
  #     http.open_timeout = 1000
  #     resp = http.head(url)
  #     Time.parse(resp['last-modified'])
  #   end
  # end
end
