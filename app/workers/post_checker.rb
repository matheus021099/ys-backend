class PostChecker
  include Sidekiq::Worker

  sidekiq_options queue: :default, unique: :until_and_while_executing

  def perform
    remove_over_24_hrs
  end

  def remove_over_24_hrs
    Post.joins(:user)
      .where.not(users: {username: ENV['PUBLIC_RELATIONS_USERNAME']})
      .where("posts.created_at < ?", 1.day.ago)
      .destroy_all
  end
end
