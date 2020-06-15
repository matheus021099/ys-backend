class Post < ApplicationRecord
  enum media_types: {
    image: 'image',
    video: 'video'
  }

  enum assoc_selectors: {
    products: 'products',
    albums: 'albums',
    playlists: 'playlists',
    reposted: 'reposted',
    downloaded: 'downloaded'
  }

  belongs_to :user
  belongs_to :assoc, polymorphic: true, optional: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :activities, as: :assoc, dependent: :destroy

  mount_uploader :media, FileUploader
  mount_uploader :cover, CoverUploader

  after_create :do_after_create

  def do_after_create
    message_body = "#{self.user.display_name} uploaded a post"
    self.description.gsub /@(\w+)/ do |username|
      username = username.gsub('@', '').downcase
      user = User.includes(:devices).find_by_username(username)
      if user.present?
        PushNotificationWorker.perform_async(
          user.devices.where(enabled: true).pluck(:token),
          FCMService::push_notification_types[:post_created],
          message_body,
          PostSerializer.new(self).as_json
        )
      end
    end.html_safe
  end

  def media_url
    if media_name.blank?
      self.media.url
    else
      self.media.url(query: {:"response-content-disposition" => "attachment; filename=\"#{media_name}\""})
    end
  end

  def play(player)
    return true if player.id == self.user_id

    played_before = Activity.where(
      sender_id: player.id,
      receiver_id: self.user_id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      action_type: Activity.action_types[:play]
    ).size > 0
    self.update_attributes(played: self.played + 1) unless played_before
  end

  def download(downloader)
    return true if downloader.id == self.user_id

    downloaded_before = Activity.where(
      sender_id: downloader.id,
      receiver_id: self.user_id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      action_type: Activity.action_types[:download]
    ).size > 0
    self.update_attributes(downloaded: self.downloaded + 1) unless downloaded_before
  end
end
