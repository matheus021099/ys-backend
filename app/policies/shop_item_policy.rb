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
    record.merchant_id == user.id
  end

  def mark_as_unshipped?
    record.merchant_id == user.id
  end

  def tickets?
    record.customer_id == user.id || record.merchant_id == user.id || user.admin?
  end
end
