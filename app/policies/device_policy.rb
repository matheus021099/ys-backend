class DevicePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end

  def create?
    true
  end

  def permitted_attributes
    [
      :identifier,
      :token,
      :platform
    ]
  end
end
