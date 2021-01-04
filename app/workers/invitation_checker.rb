class InvitationChecker
  include Sidekiq::Worker

  sidekiq_options queue: :default, unique: :until_and_while_executing

  def perform
    remove_expired
  end

  def remove_expired
    Invitation.where("status = ? AND created_at < ?", Invitation.statuses[:pending], 3.day.ago).destroy_all
  end
end
