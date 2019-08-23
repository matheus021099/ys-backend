class Device < ApplicationRecord
  enum platform: {
    ios: 'iOS',
    android: 'android'
  }

  belongs_to :user

  # validates_uniqueness_of :token, scope: :user_id
  validates_uniqueness_of :identifier, scope: :user_id
end
