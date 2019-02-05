class ShopAddressPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(customer: user)
      end
    end
  end

  def create?
    true
  end

  def update?
    user.admin? || record.customer == user
  end

  def destroy?
    user.admin? || record.customer == user
  end

  def permitted_attributes
    [
      :email,
      :first_name,
      :last_name,
      :unit,
      :street_1,
      :street_2,
      :city,
      :state,
      :country,
      :postcode,
      :phone_number
    ]
  end
end