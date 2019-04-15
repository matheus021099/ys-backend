class MessageBroadcaster
  include Sidekiq::Worker

  sidekiq_options retry: false, queue: 'low', unique: :until_and_while_executing

  # admin broadcasts a message to users
  def perform(admin_id, message_body)
    sender = User.find(admin_id) rescue nil
    return false unless sender.present?

    User.where.not(user_type: [User.user_types[:superadmin], User.user_types[:admin]]).find_each do |receiver|
      Util::Message.send(sender, receiver, message_body)
    end
  end
end
