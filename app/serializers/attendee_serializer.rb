class AttendeeSerializer < ActiveModel::Serializer
  attributes :id, :full_name, :display_name, :email, :account_type, :referred_by, :status
  # belongs_to :user

  attributes :user, :inviter

  def user
    return nil if object.user_id.blank?
    object.user.as_json(
      only: [ :id, :slug, :display_name, :avatar, :user_type ]
    )
  end

  def inviter
    return nil if object.inviter_id.blank?
    object.inviter.as_json(
      only: [ :id, :slug, :display_name, :avatar, :user_type ]
    )
  end
end
