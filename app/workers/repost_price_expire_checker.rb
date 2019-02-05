class RepostPriceExpireChecker
  include Sidekiq::Worker

  sidekiq_options queue: 'low', unique: :until_and_while_executing

  def perform
    User.where(
      'repost_price > 100 AND repost_price_end_at IS NOT NULL AND repost_price_end_at < ?', Time.now
    ).update_all(
      max_repost_price: 100,
      repost_price: 100,
      repost_price_end_at: nil
    )
  end
end
