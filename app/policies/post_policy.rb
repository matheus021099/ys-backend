class PostPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # if user.admin?
      #   scope.all
      # else
      #   scope.where(user: user)
      # end
      scope.all
    end
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    user.id == record.user_id
  end

  def destroy?
    user.id == record.user_id
  end

  def permitted_attributes
    [
      :media_type,
      :media,
      :media_name,
      :cover,
      :description,
      :cover,
      :assoc_type,
      :assoc_id,
      :assoc_selector,
    ]
  end
end
