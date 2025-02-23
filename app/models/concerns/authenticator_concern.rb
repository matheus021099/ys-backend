module AuthenticatorConcern
  extend ActiveSupport::Concern

  def current_user
    Thread.current[:user]
  end

  def self.current_user=(user)
    Thread.current[:user] = user
  end
end
