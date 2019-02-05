class ShopOrderPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(customer: user)
      end
    end
  end

  def show?
    user.admin? || record.customer_id == user.id ||
    ShopItem
      .joins(:product => [:user_products])
      .where(order_id: record.id)
      .where(users_products: {
        user_type: [
          UserProduct.user_types[:creator],
          UserProduct.user_types[:collaborator]
        ],
        status: UserProduct.statuses[:accepted],
        user_id: user.id
      }).size > 0
  end

  def hide_customer_address?
    # record.customer_id == user.id && record.status == ShopOrder.statuses[:order_shipped]
    record.customer_id == user.id && record.order_shipped?
  end
end
