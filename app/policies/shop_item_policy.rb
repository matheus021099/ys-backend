class ShopItemPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(merchant: user)
      end
    end
  end

  def mark_as_shipped?
    record.merchant == user
  end

  def mark_as_unshipped?
    record.merchant == user
  end
end