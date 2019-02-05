class UserProduct < ApplicationRecord
  self.table_name = "users_products"

  enum user_type: {
    creator: 'creator',
    collaborator: 'collaborator',
    label: 'label'
  }

  enum status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied'
  }

  belongs_to :user
  belongs_to :product, foreign_key: 'product_id', class_name: 'ShopProduct'

  validates :user, presence: true
  validates :product, presence: true

  after_initialize :set_default_values
  def set_default_values
    self.user_type ||= UserProduct.user_types[:creator]
    self.user_share ||= 100
    self.status ||= UserProduct.statuses[:accepted]
  end

end
