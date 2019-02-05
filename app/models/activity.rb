class Activity < ApplicationRecord
  # enum module_type: [:stream, :activity, :message, :cart, :log]
  # enum action_type: [
  #   :release, :follow, :unfollow, :repost, :unrepost, :play, :download, :comment,
  #   :signin, :signout, :signup, :hide, :signup_resume, :add_to_cart, :view_stream, :free_host_stream, :demand_host_stream
  # ]
  # enum status: [:unread, :read]
  enum module_type: {
    stream: 'stream',
    activity: 'activity',
    message: 'message',
    cart: 'cart',
    log: 'log'
  }
  enum action_type: {
    release: 'release',
    follow: 'follow',
    unfollow: 'unfollow',
    repost: 'repost',
    unrepost: 'unrepost',
    hide: 'hide',
    play: 'play',
    download: 'download',
    comment: 'comment',
    signin: 'signin',
    signout: 'signout',
    signup: 'signup',
    signup_resume: 'signup_resume',
    add_to_cart: 'add_to_cart',
    view_stream: 'view_stream',
    free_host_stream: 'free_host_stream',
    demand_host_stream: 'demand_host_stream'
  }
  enum status: {
    unread: 'unread',
    read: 'read'
  }
  enum alert_type: [:off, :both, :web, :app]

  belongs_to :sender, class_name: 'User'
  belongs_to :receiver, class_name: 'User'
  belongs_to :assoc, polymorphic: true, optional: true

  # default_scope { order(created_at: :desc) }

  scope :received_by, -> receiver_id { where('receiver_id = ?', receiver_id) }
  scope :sent_from, -> sender_id { where('sender_id = ?', sender_id) }

  scope :unread, -> { where(status: Activity.statuses[:unread]) }

  scope :activity, -> { where(module_type: Activity.module_types[:activity]) }
  scope :stream, -> { where(module_type: Activity.module_types[:stream]) }

  scope :for_album, -> (album_id) { where(assoc_type: 'Album', assoc_id: album_id) }

  # class method
  class << self
    def insert(
      sender_id: nil,
      receiver_id: nil,
      message: '',
      assoc_type: nil,
      assoc_id: nil,
      module_type: nil,
      action_type: nil,
      alert_type: nil,
      page_track: nil,
      status: Activity.statuses[:unread]
    )
      activity = Activity.where(
        sender_id: sender_id,
        receiver_id: receiver_id,
        assoc_type: assoc_type,
        assoc_id: assoc_id,
        module_type: module_type,
        action_type: action_type
      ).first

      if activity.blank?
        Activity.create(
          sender_id: sender_id,
          receiver_id: receiver_id,
          message: message,
          assoc_type: assoc_type,
          assoc_id: assoc_id,
          module_type: module_type,
          action_type: action_type,
          alert_type: alert_type,
          page_track: page_track,
          status: status
        )
        true
      else
        activity.update_attributes(
          message: message,
          alert_type: alert_type,
          page_track: page_track,
          status: status
        )
        false
      end
    end

    def remove(assoc_type, assoc_id)
      Activity.where({
        assoc_type: assoc_type,
        assoc_id: assoc_id
      }).delete_all
    end
  end
end
