class TicketPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def show?
    record.open_user_id == user.id || user.admin?
  end

  def create?
    true
  end

  def update?
    record.open_user_id == user.id || user.admin?
  end

  def permitted_attributes
    [
      :reason,
      :description,
      :close_user_id,
      :closed_at,
      :item_id,
      :status
    ]
  end
end
