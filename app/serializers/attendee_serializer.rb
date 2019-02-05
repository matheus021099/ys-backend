class AttendeeSerializer < ActiveModel::Serializer
  attributes :id, :full_name, :display_name, :email, :account_type, :referred_by, :status
  belongs_to :user
  # attribute :user
  # def user
  #   ActiveModel::Serializer::UserSerializer.new(object.user, scope: scope)
  # end
end