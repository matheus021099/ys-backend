class Attendee < ApplicationRecord
  enum status: {
    created: 'created',
    invited: 'invited',
    accepted: 'accepted',
    expired: 'expired',
    existed: 'existed'
  }

  validates :email, presence: :true, uniqueness: { case_sensitive: false }
  validates :display_name, presence: :true, uniqueness: { case_sensitive: false }
  validates :account_type, presence: :true

  belongs_to :user
end