class User < ApplicationRecord
  rolify

  acts_as_followable
  acts_as_follower
  acts_as_messageable
  acts_as_taggable_on :genres # hidden genres
  acts_as_taggable_on :blocks # block users
  acts_as_taggable_on :favorites # favorite users to promote

  enum user_type: {
    superadmin: 'superadmin',
    admin: 'admin',
    moderator: 'moderator',
    listener: 'listener',
    artist: 'artist',
    brand: 'brand',
    label: 'label'
  }

  # enum status: [ :inactive, :active, :verified, :suspended, :deleted ]
  enum status: {
    inactive: 'inactive',
    active: 'active',
    verified: 'verified',
    suspended: 'suspended',
    deleted: 'deleted'
  }

  enum request_status: {
    pending: 'pending',
    accepted: 'accepted',
    denied: 'denied'
  }

  mount_uploader :avatar, AvatarUploader

  serialize :data, JsonHashSerializer

  searchkick word_start: %i[id email username display_name contact_url status],
    searchable: %i[id email username display_name contact_url status]

  def search_data
    # attributes
    search_fields
  end

  def search_fields
    {
      id: id,
      email: email,
      username: username,
      user_type: user_type,
      display_name: display_name,
      contact_url: contact_url,
      request_role: request_role,
      request_status: request_status,
      inviter_id: inviter_id,
      created_at: created_at,
      status: status
    }
  end

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable,
         :validatable, :confirmable

  # validates :first_name, presence: true
  # validates :last_name, presence: true
  # validates :avatar, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  # validates :email, presence: { if: -> { social_user_id.blank? } }
  validates :username, presence: :true, uniqueness: { case_sensitive: false }
  validates_format_of :username, with: /^[a-z0-9_.]{3,20}$/, multiline: true

  belongs_to :approver, foreign_key: 'approver_id', class_name: 'User'
  belongs_to :inviter, foreign_key: 'inviter_id', class_name: 'User'
  # main_genre
  belongs_to :genre

  has_one :stream, -> { where.not status: Stream.statuses[:deleted] }

  has_many :devices
  has_many :user_albums
  has_many :albums, through: :user_albums
  # has_many :albums, -> { where status: UserAlbum.statuses[:accepted] }, through: :user_albums
  has_many :tracks
  has_many :feeds
  has_many :playlists, -> { where album_type: Album.album_types[:playlist] }, class_name: 'Album'

  has_many :products, foreign_key: 'merchant_id', class_name: 'ShopProduct'
  has_many :variants, through: :products

  has_many :addresses, foreign_key: 'customer_id', class_name: 'ShopAddress'
  belongs_to :default_address, foreign_key: 'address_id', class_name: 'ShopAddress'

  # default
  after_initialize :set_default_values
  def set_default_values
    self.user_type ||= User.user_types[:listener]
    self.status ||= User.statuses[:inactive]
  end

  before_save :downcase_fields
  def downcase_fields
    self.email.downcase! unless self.email.blank?
    self.username.downcase! unless self.username.blank?
  end

  # slug
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged #use: [:slugged, :finders]
  def slug_candidates
    [ :username ]
  end

  # role
  # after_create :assign_default_role
  # def assign_default_role
  #   self.add_role(:listener) if self.roles.blank?
  # end

  def apply_role role
    # ActiveRecord::Base.connection.execute("DELETE FROM users_roles WHERE user_id = '#{self.id}' "\
    #    "AND role_id IN (SELECT id FROM roles WHERE resource_type IS NULL)")
    # self.add_role role
    self.update_attributes(user_type: role)
  end

  # superadmin
  def self.superadmin
    @@superadmin ||= User.find_by(email: ENV['SUPERADMIN_EMAIL']) || User.where(user_type: User.user_type[:superadmin]).first
  end

  def self.admin
    @@admin ||= User.find_by(email: ENV['ADMIN_EMAIL']) || User.where(user_type: User.user_type[:admin]).first
  end

  def current_cart
    ShopCart.find_or_create_by(customer_id: self.id)
  end

  def active_for_authentication?
    super and self.active?
  end

  def available_amount
    pending_received_amount = Payment.where(receiver_id: self.id, status: Payment.statuses[:pending]).sum(:received_amount)
    self.balance_amount - pending_received_amount
  end

  def available_stream_period
    3600 * self.balance_amount / Payment::STREAM_HOURLY_PRICE
  end

  def stripe_connected?
    self.payment_account_id.present?
  end

  def hidden_genre_objects
    # Genre.where(name: self.genre_list)
    Genre.where(id: self.genre_list)
  end

  def blocked_album_ids
    exclude_album_ids = [0]

    # albums which are type of genres blocked
    hidden_album_ids = Album.tagged_with(self.genre_list, :on => :genres, :any => true).pluck(:id)
    exclude_album_ids.concat hidden_album_ids

    # albums which are uploaded by users who go under block list
    hidden_album_ids = Album.where(user_id: self.block_list).pluck(:id)
    exclude_album_ids.concat hidden_album_ids

    # albums which are hidden
    hidden_album_ids = Feed.where(publisher_id: self.id, feed_type: Feed.feed_types[:hide], assoc_type: 'Album').pluck(:assoc_id)
    exclude_album_ids.concat hidden_album_ids

    exclude_album_ids
  end

  def blocked_user_objects
    User.where(id: self.block_list)
  end

  def favorite_user_objects
    User.where(id: self.favorite_list)
  end

  def repost_price_proration(new_repost_price = 100)
    new_repost_price  ||= 100
    now = Time.zone.now

    return {
      # max_repost_price: self.max_repost_price,
      add_amount: 0,
      expire_at: self.repost_price_end_at
    } if new_repost_price == 100

    return {
      # max_repost_price: new_repost_price,
      add_amount: new_repost_price,
      expire_at: now.since(1.year)
    } if self.repost_price_end_at.nil? || self.repost_price_end_at <= now

    return {
      # max_repost_price: self.max_repost_price,
      add_amount: 0,
      expire_at: self.repost_price_end_at
    } if new_repost_price <= self.max_repost_price

    return {
      # max_repost_price: new_repost_price,
      add_amount: new_repost_price,
      expire_at: self.repost_price_end_at.since(1.year)
    } if self.repost_price_end_at.ago(6.months) < now

    spent_amount = self.max_repost_price > 100 ? self.max_repost_price / 2 : 0
    return {
      # max_repost_price: new_repost_price,
      add_amount: new_repost_price - spent_amount,
      expire_at: self.repost_price_end_at
    }
  end

  def remove
    # Activity.create(
    #   sender_id: self.id,
    #   receiver_id: self.id,
    #   message: 'close account',
    #   module_type: Activity.module_types[:activity],
    #   action_type: Activity.action_types[:close],
    #   alert_type: Activity.alert_types[:both],
    #   status: Activity.statuses[:read]
    # )

    # user.apply_role(:listener)
    self.update_attributes(
      confirmed_at: nil,
      confirmation_sent_at: nil,
      status: User.statuses[:deleted]
    )
  end

  # some fields for mailboxer
  def name
    "#{first_name} #{last_name}"
  end

  def mailboxer_email
    self.email
  end

  # send love donation
  def donate(receiver: nil, amount: 0, payment_token: nil, description: '')
    return 'Not found receiver' unless receiver.present?

    sender = self
    stripe_charge_id = nil
    unless payment_token.blank?
      # fee = Payment.stripe_fee(amount)
      stripe_charge_id = Payment.deposit(user: sender, payment_token: payment_token, amount: amount)
      return 'Failed in stripe charge' if stripe_charge_id === false
    else
      stripe_charge_id = nil
      return 'Not enough balance' if sender.balance_amount < amount
    end

    fee = Payment.calculate_fee(amount, 'donation', description.downcase)
    received_amount = amount - fee
    payment = nil
    ActiveRecord::Base.transaction do
      payment = Payment.donate(
        sender: sender,
        receiver: receiver,
        description: description,
        sent_amount: amount,
        received_amount: received_amount,
        fee: fee,
        payment_token: payment_token
      )
    end
    payment
  end

  def recent_items(user, filter = 'any', count = 6)
    case filter
      when 'uploaded'
        feed_type = Feed.feed_types[:release].to_s
      when 'reposted'
        feed_type = Feed.feed_types[:repost].to_s
      when 'downloaded'
        feed_type = Feed.feed_types[:download].to_s
      else
        feed_type = 'any'
    end

    case filter
      when 'any'
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
            .most_recent
            .limit(count)
      when 'uploaded'
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(feeds.id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' AND assoc_type='Album' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .joins("LEFT JOIN albums t3 ON t1.assoc_id = t3.id")
            .where('t3.album_type = ? AND t1.assoc_id NOT IN (?)', Album.album_types[:album], self.blocked_album_ids)
            .most_recent
            .limit(count)
      when 'playlist'
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(feeds.id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' AND assoc_type='Album' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .joins("LEFT JOIN albums t3 ON t1.assoc_id = t3.id")
            .where('t3.album_type = ? AND t1.assoc_id NOT IN (?)', Album.album_types[:playlist], self.blocked_album_ids)
            .most_recent
            .limit(count)
      when 'merch'
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' AND assoc_type = 'ShopProduct' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .where('t1.assoc_type = ?', 'ShopProduct')
            .most_recent
            .limit(count)
      when 'video'
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' AND assoc_type = 'Stream' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .where('t1.assoc_type = ?', 'Stream')
            .most_recent
            .limit(count)
      # else
      #   query = Feed
      #       .select('t1.*')
      #       .from('feeds t1')
      #       .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds "\
      #           "WHERE publisher_id = '#{self.id}' AND assoc_type = 'Album' AND feed_type = '#{feed_type}' "\
      #           "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
      #       .where('t1.assoc_type = ? AND t1.assoc_id NOT IN (?)', 'Album', self.blocked_album_ids)
      #       .most_recent
      #       .limit(count)
      else
        query = Feed
            .select('t1.*')
            .from('feeds t1')
            .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds "\
                "WHERE publisher_id = '#{self.id}' AND feed_type = '#{feed_type}' "\
                "GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
            .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
            .most_recent
            .limit(count)
    end
  end

  # queries
  def feed_query_v2(filter, genre)
    case filter
      when 'uploaded'
        feed_type = Feed.feed_types[:release].to_s
      when 'reposted'
        feed_type = Feed.feed_types[:repost].to_s
      when 'downloaded'
        feed_type = Feed.feed_types[:download].to_s
      else
        feed_type = 'any'
    end

    blocked_user_ids = []
    blocked_user_ids << self.id
    blocked_user_ids.concat self.block_list
    case filter
      when 'any'
        query = User
            .select('t1.*')
            .from('users t1')
            .joins("RIGHT JOIN (SELECT publisher_id, MAX(created_at) AS created_at FROM feeds "\
                "WHERE consumer_id = '#{self.id}' AND publisher_id NOT IN ('#{blocked_user_ids.join("', '")}') "\
                  "AND (assoc_type != 'Album' OR (assoc_type = 'Album' AND assoc_id NOT IN ('#{self.blocked_album_ids.join("', '")}'))) "\
                "GROUP BY publisher_id ORDER BY created_at) t2 ON t1.id = t2.publisher_id")
            .order('t2.created_at DESC')
      when 'playlist'
        query = User
            .select('t1.*')
            .from('users t1')
            .joins("RIGHT JOIN (SELECT publisher_id, MAX(feeds.created_at) AS created_at FROM feeds "\
                "LEFT JOIN albums ON feeds.assoc_id = albums.id "\
                "WHERE consumer_id = '#{self.id}' AND publisher_id NOT IN ('#{blocked_user_ids.join("', '")}') AND albums.album_type = '#{Album.album_types[:playlist].to_s}' AND assoc_type = 'Album' AND assoc_id NOT IN ('#{self.blocked_album_ids.join("', '")}') "\
                "GROUP BY publisher_id ORDER BY created_at) t2 ON t1.id = t2.publisher_id")
            .order('t2.created_at DESC')
      when 'merch'
        query = User
            .select('t1.*')
            .from('users t1')
            .joins("RIGHT JOIN (SELECT publisher_id, MAX(created_at) AS created_at FROM feeds "\
                "WHERE consumer_id = '#{self.id}' AND publisher_id NOT IN ('#{blocked_user_ids.join("', '")}') "\
                  "AND assoc_type = 'ShopProduct' "\
                "GROUP BY publisher_id ORDER BY created_at) t2 ON t1.id = t2.publisher_id")
            .order('t2.created_at DESC')
      when 'video'
        query = User
            .select('t1.*')
            .from('users t1')
            .joins("RIGHT JOIN (SELECT publisher_id, MAX(created_at) AS created_at FROM feeds "\
                "WHERE consumer_id = '#{self.id}' AND publisher_id NOT IN ('#{blocked_user_ids.join("', '")}') "\
                  "AND assoc_type = 'Stream' "\
                "GROUP BY publisher_id ORDER BY created_at) t2 ON t1.id = t2.publisher_id")
            .order('t2.created_at DESC')
      else
        query = User
            .select('t1.*')
            .from('users t1')
            .joins("RIGHT JOIN (SELECT publisher_id, MAX(created_at) AS created_at FROM feeds "\
                "WHERE consumer_id = '#{self.id}' AND publisher_id NOT IN ('#{blocked_user_ids.join("', '")}') "\
                  "AND (assoc_type = 'Album' AND assoc_id NOT IN ('#{self.blocked_album_ids.join("', '")}')) "\
                  "AND feed_type = '#{feed_type}' "\
                "GROUP BY publisher_id ORDER BY created_at) t2 ON t1.id = t2.publisher_id")
            .order('t2.created_at DESC')
    end

    # query = query.page(page).per_page(per_page)
  end

  def feed_query(filter, genre)
    ##TODO - you can change Feed with Activity
    case filter
      when 'downloaded'
        query = Feed
          .select('t1.*')
          .from('feeds t1')
          .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:download]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
          .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
          .most_recent
      when 'uploaded'
        query = Feed
          .select('t1.*')
          .from('feeds t1')
          .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:release]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
          .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
          .most_recent
      when 'reposted'
        query = Feed
          .select('t1.*')
          .from('feeds t1')
          .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:repost]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
          .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
          .most_recent
      when 'playlist'
        query = Feed
          .select('t1.*')
          .from('feeds t1')
          .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' AND assoc_type='Album' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
          .joins('JOIN albums t3 ON t3.id = t2.assoc_id')
          .where('t3.album_type = ? AND t1.assoc_id NOT IN (?)', Album.album_types[:playlist], self.blocked_album_ids)
          .most_recent
      # when 'merch'
      #   query = Feed
      #     .select('t1.*')
      #     .from('feeds t1')
      #     .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:merch]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
      #     .where('t1.assoc_type != ?', 'Album')
      #     .most_recent
      else
        query = Feed
          .select('t1.*')
          .from('feeds t1')
          .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE consumer_id = '#{self.id}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
          .where('t1.assoc_type != ? OR (t1.assoc_type = ? AND t1.assoc_id NOT IN (?))', 'Album', 'Album', self.blocked_album_ids)
          .most_recent
    end
    # query = query.page(page).per_page(per_page)
  end

  def album_query(filter, genre)
    # query = self.albums.published.not_playlists
    query = Album.joins(:user_albums)
      .where(
        users_albums: {
          user_id: self.id,
          user_type: [
            UserAlbum.user_types[:creator],
            UserAlbum.user_types[:collaborator],
            UserAlbum.user_types[:label]
          ]
        },
        album_type: Album.album_types[:album],
      )
      .where(
        is_only_for_live_stream: false,
        status: [Album.statuses[:published], Album.statuses[:collaborated]]
      )

    case filter
      when 'new'
        query = query.most_recent
      when 'popular'
        query = query.most_downloaded
    end

    unless genre.eql?('any')
      # query = query.joins('INNER JOIN follows f ON f.follower_id = albums.id').where('f.followable_type=? AND f.followable_id=?', 'Genre', genere_obj.id)
      query = query.tagged_with(genre, :on => :genres)
    end

    query
  end

  def playlist_query(filter, genre)
    # query = self.albums.published.playlists
    query = Album.joins(:user_albums)
      .where(
        users_albums: { user_id: self.id },
        album_type: Album.album_types[:playlist]
      )
      .where(status: [Album.statuses[:published], Album.statuses[:collaborated]])

    case filter
      when 'popular'
        query = query.most_downloaded#.most_recent
      # when 'new'
      else
        query = query.most_recent
    end

    unless genre.eql?('any')
      query = query.tagged_with(genre, :on => :genres)
    end

    query
  end

  def download_query(filter, genre)
    items = Feed
      .select('t1.*')
      .from('feeds t1')
      .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE publisher_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:download]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
    album_ids = items.map{ |item| item.assoc_id }
    query = Album.where(id: album_ids)
  end

  def repost_query(filter, genre)
    items = Feed
      .select('t1.*')
      .from('feeds t1')
      .joins("RIGHT JOIN (SELECT MAX(id) AS id, assoc_id, assoc_type FROM feeds WHERE publisher_id = '#{self.id}' AND feed_type = '#{Feed.feed_types[:repost]}' GROUP BY assoc_id, assoc_type) t2 ON t1.id = t2.id")
      .order('updated_at desc')
    # album_ids = items.map{ |item| item.assoc_id }
    # query = Album.where(id: album_ids)
  end

  def follower_query(filter)
    case filter
      when 'listener'
        User
          .joins("INNER JOIN follows ON users.id = follows.follower_id")
          .where(
            users: {
              status: User.statuses[:active],
              user_type: User.user_types[:listener]
            },
            follows: {
              blocked: false,
              followable_id: self.id
            }
          )
      when 'artist'
        User
          .joins("RIGHT JOIN follows ON users.id = follows.follower_id")
          .where(
            users: {
              status: User.statuses[:active],
              user_type: User.user_types[:artist]
            },
            follows: {
              blocked: false,
              followable_id: self.id
            }
          )
      else
        User
          .joins("RIGHT JOIN follows ON users.id = follows.follower_id")
          .where(
            users: {status: User.statuses[:active]},
            follows: {blocked: false, followable_id: self.id}
          )
    end
  end

  def following_query(filter)
    # users = Follow.where(follower_id: @user.id).where(blocked: false).order('created_at desc')
    # case filter
    #   when 'listeners'
    #     users = users.joins("INNER JOIN users ON users.id = follows.followable_id").where(follows: {followable_type: 'User'}).where(users: {artist: false, status: 'active'})
    #   when 'artists'
    #     users = users.joins("INNER JOIN users ON users.id = follows.followable_id").where(follows: {followable_type: 'User'}).where(listeners: {artist: true, status: 'active'})
    #   else
    #     users = users.joins("INNER JOIN users ON users.id = follows.followable_id").where(follows: {followable_type: 'User'}).where(listeners: {status: 'active'})
    # end

    # users = User
    #   .find_roles(:listener)
    #   .where(status: User.statuses[:active])
    #   .joins("RIGHT JOIN follows ON users.id = follows.followable_id")
    #   .where(follows: {blocked: false, follower_id: @user.id})

    case filter
      when 'listener'
        User
          .joins(
            "INNER JOIN follows ON users.id = follows.followable_id"
          )
          .where(
            users: {
              status: User.statuses[:active],
              user_type: User.user_types[:listener]
            },
            follows: {
              blocked: false,
              follower_id: self.id
            }
          )
          # .where.not(roles: {name: ['artist', 'admin']})
      when 'artist'
        User
          .joins("RIGHT JOIN follows ON users.id = follows.followable_id")
          .where(
            users: {
              status: User.statuses[:active],
              user_type: User.user_types[:artist]
            },
            follows: {
              blocked: false,
              follower_id: self.id
            }
          )
      else
        User
          .joins("RIGHT JOIN follows ON users.id = follows.followable_id")
          .where(
            users: {status: User.statuses[:active]},
            follows: {blocked: false, follower_id: self.id}
          )
    end
  end

  def sample_following_query
    users_ids = User
      .joins("RIGHT JOIN follows ON users.id = follows.followable_id")
      .joins("JOIN albums ON users.id = albums.user_id")
      .where(
        users: {
          status: User.statuses[:active],
          user_type: User.user_types[:artist]
        },
        follows: {
          blocked: false,
          follower_id: self.id
        },
        albums: {
          enabled_sample: true
        }
      ).group(:id).count.keys

    User.where(id: users_ids)
  end

  class << self
    # def find_by_username(username)
    #   User.where('lower(username) = ?', username.downcase).first
    # end

    def from_omniauth(info)
      user = where(social_provider: info[:provider], social_user_id: info[:user_id]).first_or_initialize do |u|
        u.social_user_id = info[:user_id]
        u.social_user_name = info[:user_name]
        u.social_token = info[:token]
        u.social_token_secret = info[:token_secret]
      end
      if user.new_record?
        user.email = info[:email]
        user.password = Devise.friendly_token[0,20]
        user.username = info[:user_name]
        user.status = User.statuses[:verified]
        user.add_role(:artist)
        user.save
        # user.save(validate: false)
      end
      user
    end

    def explore_query(q, filter, genre, params = {}, user = nil)
      where = {
        # released: true,
        is_only_for_live_stream: false,
        status: ['published', 'collaborated']
      }
      order = {}
      case filter
        when 'new'
          order[:created_at] = {
            order: 'desc',
            # ignore_unmapped: true,
            unmapped_type: 'long'
          }
          where[:album_type] = 'album'
        when 'popular'
          order[:created_at] = {
            order: 'desc',
            # ignore_unmapped: true,
            unmapped_type: 'long'
          }
          where[:playlist] = 'album'
        when 'playlist'
          order[:created_at] = {
            order: 'desc',
            # ignore_unmapped: true,
            unmapped_type: 'long'
          }
          where[:album_type] = 'playlist'
        when 'recommended'
          order[:recommended_at] = {
            order: 'desc',
            # ignore_unmapped: true,
            unmapped_type: 'long'
          }
          where[:recommended] = true
      end

      unless genre.eql?('any')
        album_tagged_with_genre = Album.tagged_with(genre).map(&:id)

        include_album_ids = album_tagged_with_genre
        unless include_album_ids.blank?
          where[:id] = {} if where[:id].blank?
          where[:id][:in] = include_album_ids
        end
      end

      exclude_album_ids = [0]
      unless user.blank?
        exclude_album_ids = user.blocked_album_ids
      end
      unless exclude_album_ids.blank?
        where[:id] = {} if where[:id].blank?
        where[:id][:not] = exclude_album_ids
      end

      params = params.merge(per_page: Album.default_per_page) if params[:per_page].blank?
      params = params.merge(where: where, order: order)
      params = params.merge(includes: [:tracks, :album_tracks, :user_albums, :user, :genres, :products])

      Album.search q.presence || '*', params
    end

    def valid_token?(token)
      payload = JsonWebToken.decode(token)
      user = User.where(id: payload['id'], username: payload['username']).first
    rescue JWT::ExpiredSignature
      return 'Auth token has expired'
    rescue Exception
      return 'Invalid auth token'
    end
  end
end
