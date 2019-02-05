class ShopProductPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(merchant: user)
      end
    end
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    user.admin? || record.merchant == user
  end

  def destroy?
    user.admin? || record.merchant == user
  end

  def release?
    record.merchant == user
  end

  def repost?
    user.id != record.merchant_id
  end

  def unrepost?
    moderate?
  end

  def accept_collaboration?
    true
  end

  def deny_collaboration?
    true
  end

  def permitted_attributes
    [
      :name,
      :description,
      :stock_status,
      :category_id,
      :price,
      :show_status,
      :tax_percent,
      :is_vat,
      :seller_location,
      :digital_content_name,
      # covers_attributes: [
      #   {:id, :_destroy}
      # ]

      # shop_product[covers_attributes][][id]
      # shop_product[covers_attributes][][file]
    ]
  end

  private
  def moderate?
    Feed.where(consumer_id: user.id, assoc_type: 'ShopProduct', assoc_id: record.id).size > 0
  end
end