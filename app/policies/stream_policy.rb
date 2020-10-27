class StreamPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user: user)
      end
    end
  end

  def show?
    true
    # record.user_id == user.id
  end

  def create?
    # user.artist? || user.brand? || user.label?
    record.new_record? || record.deleted?
  end

  def update?
    record.user_id == user.id
  end

  def destroy?
    !record.deleted? && (record.user_id == user.id || user.admin?)
  end

  def notify?
    record.user_id == user.id && record.running?
  end

  def start?
    record.user_id == user.id && record.active?
  end

  def stop?
    record.user_id == user.id && record.running?
  end

  def repost?
    record.user_id != user.id
  end

  def view?
    record.user_id != user.id
  end

  def permitted_attributes
    [
      :name,
      :viewers_limit,
      :view_price,
      :assoc_type,
      :assoc_id
    ]
  end
end
