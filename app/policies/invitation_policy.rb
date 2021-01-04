class InvitationPolicy < ApplicationPolicy
  def create?
    !user.listener?
  end
end
