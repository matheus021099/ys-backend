class CommentPolicy < ApplicationPolicy
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
    true
  end

  def destroy?
    record.user_id == user.id || record.commentable.user_id == user.id
  end 

  def make_public?
    record.commentable.user_id == user.id
  end

  def make_private?
    record.commentable.user_id == user.id
  end

  def permitted_attributes
    [ 
      :commentable_type,
      :commentable_id,
      :body
    ]
  end
end