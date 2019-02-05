class GenrePolicy < ApplicationPolicy
#   class Scope < Scope
#     def resolve
#       if user.admin?
#         scope.all
#       else
#         scope.where(user: user)
#       end
#     end
#   end

  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  def permitted_attributes
    [:name]
  end
end