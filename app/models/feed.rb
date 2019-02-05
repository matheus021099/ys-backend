class Feed < ApplicationRecord
  # enum feed_type: [:release, :repost, :play, :download, :merch, :hide]
  enum feed_type: {
    release: 'release',
    repost: 'repost',
    play: 'play',
    download: 'download',
    merch: 'merch',
    hide: 'hide'
  }

  belongs_to :consumer, class_name: 'User'
  belongs_to :publisher, class_name: 'User'
  belongs_to :assoc, polymorphic: true, optional: true

  scope :most_recent, -> {order('created_at desc')}

  # class method
  def self.insert(consumer_id: nil, publisher_id: nil, assoc_type: nil, assoc_id: nil, feed_type: nil)
    Feed.where({
      consumer_id: consumer_id,
      publisher_id: publisher_id,
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      feed_type: Feed.feed_types[:hide]
    }).delete_all unless feed_type == Feed.feed_types[:hide]

    feed = Feed.where({
      consumer_id: consumer_id,
      publisher_id: publisher_id,
      assoc_type: assoc_type,
      assoc_id: assoc_id,
      feed_type: feed_type
    }).first

    if feed.blank?
      Feed.create({
        consumer_id: consumer_id,
        publisher_id: publisher_id,
        assoc_type: assoc_type,
        assoc_id: assoc_id,
        feed_type: feed_type
      })
      true
    else
      # feed.update_attributes({
      #   feed_type: feed_type
      # })
      false
    end
  end
end