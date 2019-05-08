class UserSerializer1 < ActiveModel::Serializer
  attributes :id, :slug, :username, :display_name, :user_type, :avatar
  attribute :is_following, if: :include_is_following?

  def is_following
    if scope && scope.current_user
      return scope.current_user.following?(object)
    else
      return nil
    end
  end

  def include_is_following?
    instance_options[:include_is_following] || false
  end
end
