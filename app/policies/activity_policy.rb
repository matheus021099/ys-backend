class ActivityPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # if user.admin?
      #   scope.all
      # else
      #   scope.where(receiver: user)
      # end
      scope.where(receiver: user)
    end
  end
end