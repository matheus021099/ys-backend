class PostChecker
  include Sidekiq::Worker

  sidekiq_options queue: 'high', unique: :until_and_while_executing

  def perform
    remove_over_24_hrs
  end

  def remove_over_24_hrs
    Post.where("created_at < ?", 1.day.ago).destroy_all
  end
end
