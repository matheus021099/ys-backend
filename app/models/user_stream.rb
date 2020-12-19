class UserStream < ApplicationRecord
  self.table_name = "users_streams"

  enum user_type: {
    creator: 'creator',
    collaborator: 'collaborator',
  }

  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied'
  }

  belongs_to :user
  belongs_to :stream

  validates :user, presence: true
  validates :stream, presence: true

  after_initialize :set_default_values
  def set_default_values
    self.user_type ||= UserStream.user_types[:creator]
    self.user_share ||= 100
    self.status ||= UserStream.statuses[:accepted]
  end
end
