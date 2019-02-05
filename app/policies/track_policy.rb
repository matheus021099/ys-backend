class TrackPolicy < ApplicationPolicy
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

  def update?
    user.admin? || record.user == user
  end

  def destroy?
    user.admin? || record.user == user
  end

  def download?
    true
  end

  def play?
    true
  end

  def permitted_attributes
    [
      :name,
      :description,
      :audio
    ]
  end
end