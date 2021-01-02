class Invitation < ApplicationRecord
  enum status: {
    pending: 'pending',
    expired: 'expired',
    accepted: 'accepted'
  }

  belongs_to :user
  belongs_to :inviter, class_name: 'User'

  after_initialize :set_default_values
  def set_default_values
    self.status ||= Invitation.statuses[:accepted]
  end

  def new_invitation_token
    SecureRandom.urlsafe_base64(16)
  end
end
