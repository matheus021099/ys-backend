class MessagePolicy < ApplicationPolicy
  # class Scope < Scope
  #   def resolve
  #     if user.admin?
  #       scope.all
  #     else
  #       scope.where(user: user)
  #     end
  #   end
  # end

  def create?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  def conversations?
    true
  end

  def accept_repost?
    true
  end

  def permitted_attributes
    []
  end
end