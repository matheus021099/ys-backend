class ShopProduct < ApplicationRecord
  # enum status: [:draft, :privated, :published, :pending, :collaborated, :deleted]
  enum status: {
    draft: 'draft',
    privated: 'privated',
    published: 'published',
    pending: 'pending',
    collaborated: 'collaborated',
    deleted: 'deleted'
  }
  enum stock_status: {
    inactive: 'inactive',
    active: 'active',
    hidden: 'hidden',
    sold_out: 'sold_out',
    coming_soon: 'coming_soon'
  }
  enum show_status: {
    show_all: 'show_all',
    show_only_stream: 'show_only_stream'
  }

  mount_uploader :digital_content, FileUploader

  paginates_per 25

  searchkick word_start: %i[id name description merchant_username merchant_display_name],
    searchable: %i[id name description merchant_username merchant_display_name]

  def search_data
    attributes.merge(search_custom_fields)
  end

  def search_custom_fields
    {
      category_name: self.category.name,
      merchant_username: self.merchant.username,
      merchant_display_name: self.merchant.display_name
    }
  end

  validates :name, presence: true, on: :create

  before_destroy :do_before_destroy
  def do_before_destroy
    attachment_ids = Attachment.where(
      attachable_type: self.class.name,
      attachable_id: self.id,
    ).pluck(:id)

    Payment.where(attachment_id: attachment_ids).delete_all

    Attachment.where(id: attachment_ids).each do |attachment|
      attachment.message.destroy if attachment.message.present?
      attachment.delete
    end

    Activity.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Feed.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).delete_all

    Comment.where(
      commentable_type: self.class.name,
      commentable_id: self.id
    ).delete_all

    Stream.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).update_all(
      assoc_type: nil,
      assoc_id: nil
    )

    Post.where(
      assoc_type: self.class.name,
      assoc_id: self.id
    ).update_all(
      assoc_type: nil,
      assoc_id: nil
    )

    user_products = self.user_products.includes(:user).where(users_products: {
      user_type: UserProduct.user_types[:collaborator],
      # status: UserProduct.statuses[:accepted]
    })
    message_body = "#{self.merchant.display_name} has deleted a product: <b>#{self.name}</b>"
    user_products.each do |up|
      collaborator = up.user
      Util::Message.send(self.merchant, collaborator, message_body)
    end
  end

  belongs_to :merchant, foreign_key: 'merchant_id', class_name: 'User'
  belongs_to :category, foreign_key: 'category_id', class_name: 'ShopCategory'
  has_many :user_products, foreign_key: 'product_id', dependent: :destroy
  has_many :variants, foreign_key: 'product_id', class_name: 'ShopProductVariant', dependent: :destroy
  has_many :shipments, foreign_key: 'product_id', class_name: 'ShopProductShipment', dependent: :destroy
  has_many :covers, -> { order(position: :asc) }, foreign_key: 'product_id', class_name: 'ShopProductCover', dependent: :destroy
  has_many :items, foreign_key: 'product_id', class_name: 'ShopItem', dependent: :destroy

  accepts_nested_attributes_for :variants
  accepts_nested_attributes_for :shipments
  accepts_nested_attributes_for :covers

  scope :published, -> { where('status = ?', ShopProduct.statuses[:published]) }

  # define alias attributes
  alias_attribute :user_id, :merchant_id
  alias_attribute :user, :merchant

  # default
  after_initialize :set_default_values
  def set_default_values
    self.status ||= ShopProduct.statuses[:draft]
    self.stock_status ||= ShopProduct.stock_statuses[:active]
    self.released ||= false
  end

  # after_commit :update_carts, on: :update
  # def update_carts
  #   if self.stock_status != ShopProduct.stock_statuses[:active] ||
  #     (self.status != ShopProduct.statuses[:published] && self.status != ShopProduct.statuses[:collaborated])
  #     self.items.delete_all
  #   end
  # end

  def digital_content_url
    self.digital_content.url(query: {:"response-content-disposition" => "attachment; filename=\"#{digital_content_name}\""})
  end

  def stock
    total = 0

    self.variants.each do |v|
      total += v.quantity || 0
    end

    # object.items.not_ordered.each do |i|
    #   total += i.quantity
    # end

    total
  end

  def shipping_price_for_location(count_in_cart = 1, country = ShopAddress::COUNTRY_EVERYWHERE_ELSE)
    shipment = self.shipments.where(country: country).first
    if shipment.present?
      count_in_cart > 1 ? shipment.shipment_with_price : shipment.shipment_alone_price
    else
      shipment = self.shipments.where(country: ShopAddress::COUNTRY_EVERYWHERE_ELSE).first
      if shipment.present?
        count_in_cart > 1 ? shipment.shipment_with_price : shipment.shipment_alone_price
      else
        0
      end
    end
  end

  def tax_percent_for_location(country = ShopAddress::COUNTRY_EVERYWHERE_ELSE, state = '')
    state = state || ''
    tax = 0
    if self.is_vat
      tax = self.tax_percent if self.seller_location == country
    else
      tax = self.tax_percent if self.seller_location == ShopAddress::US_STATES[state.to_sym]
    end

    # puts "\n\n +++++ tax_percent_for_location +++++"
    # puts "#{country} : #{state} : #{ShopAddress::US_STATES[state.to_sym]} : #{self.seller_location} : #{tax_percent}"
    # puts "\n\n\n"

    tax
  end

  # def remove
  #   # paid_repost_exists = Attachment.where(
  #   #   attachable_type: 'ShopProduct',
  #   #   attachable_id: self.id,
  #   #   attachment_type: Attachment.attachment_types[:repost]
  #   # ).size > 0
  #   # self.update_attributes(status: ShopProduct.statuses[:deleted]) and return if paid_repost_exists
  #   ActiveRecord::Base.transaction do
  #     attachment_ids = Attachment.where(
  #       attachable_type: self.class.name,
  #       attachable_id: self.id,
  #     ).pluck(:id)
  #     Payment.where(attachment_id: attachment_ids).delete_all
  #     Attachment.where(id: attachment_ids).each do |attachment|
  #       attachment.message.destroy
  #       attachment.delete
  #     end
  #     Activity.where(
  #       assoc_type: self.class.name,
  #       assoc_id: self.id
  #     ).delete_all
  #     Feed.where(
  #       assoc_type: self.class.name,
  #       assoc_id: self.id
  #     ).delete_all
  #     Comment.where(
  #       commentable_type: self.class.name,
  #       commentable_id: self.id
  #     ).delete_all
  #     Stream.where(
  #       assoc_type: self.class.name,
  #       assoc_id: self.id
  #     ).update_all(
  #       assoc_type: nil,
  #       assoc_id: nil
  #     )
  #     Post.where(
  #       assoc_type: self.class.name,
  #       assoc_id: self.id
  #     ).update_all(
  #       assoc_type: nil,
  #       assoc_id: nil
  #     )
  #     user_products = self.user_products.includes(:user).where(users_products: {
  #       user_type: UserProduct.user_types[:collaborator],
  #       # status: UserProduct.statuses[:accepted]
  #     })
  #     message_body = "#{self.merchant.display_name} has deleted a product: <b>#{self.name}</b>"
  #     user_products.each do |up|
  #       collaborator = up.user
  #       Util::Message.send(self.merchant, collaborator, message_body)
  #     end
  #     # product_in_used = self.items.ordered.size > 0
  #     # self.update_attributes(status: ShopProduct.statuses[:deleted]) and return if product_in_used
  #     self.destroy
  #   end
  # end

  def has_pending_collaborators?
    UserProduct.where(
      product_id: self.id,
      user_type: UserProduct.user_types[:collaborator],
      status: UserProduct.statuses[:pending]
    ).size > 0
  end

  def release
    if self.show_only_stream?
      Feed.where(
        assoc_type: self.class.name,
        assoc_id: self.id
      ).delete_all

      Activity.where(
        assoc_type: self.class.name,
        assoc_id: self.id,
      ).where.not(action_type: Activity.action_types[:add_to_cart]).delete_all
    end

    return if self.released
    return if self.collaborators_count != 0 && self.has_pending_collaborators?

    new_status = self.collaborators_count == 0 ? ShopProduct.statuses[:published] : ShopProduct.statuses[:collaborated]
    self.update_attributes(
      status: new_status,
      released: true,
      released_at: Time.now.utc
    )

    return if self.show_only_stream?

    current_user = self.merchant

    Feed.insert(
      consumer_id: current_user.id,
      publisher_id: current_user.id,
      assoc_type: 'ShopProduct',
      assoc_id: self.id,
      feed_type: Feed.feed_types[:release]
    )

    Activity.create(
      sender_id: current_user.id,
      receiver_id: current_user.id,
      message: 'release a product',
      assoc_type: 'ShopProduct',
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:release],
      alert_type: Activity.alert_types[:both],
      status: Activity.statuses[:read]
    )

    current_user.followers.each do |follower|
      next if follower.blank?
      next if follower.id == self.merchant_id

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: current_user.id,
        assoc_type: 'ShopProduct',
        assoc_id: self.id,
        feed_type: Feed.feed_types[:release]
      )

      # if feed && follower.enable_alert?
      #   Activity.create(
      #     sender_id: current_user.id,
      #     receiver_id: follower.id,
      #     message: 'updated your stream',
      #     assoc_type: 'ShopProduct',
      #     assoc_id: self.id,
      #     module_type: Activity.module_types[:stream],
      #     action_type: Activity.action_types[:release],
      #     alert_type: Activity.alert_types[:both],
      #     status: Activity.statuses[:unread]
      #   )
      # end
    end
  end

  def repost(reposter, page_track = nil)
    return 'you are trying to repost your product' if reposter.id == self.merchant_id

    feed = Feed.insert(
      consumer_id: reposter.id,
      # publisher_id: self.merchant_id,
      publisher_id: reposter.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:repost]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: self.merchant_id,
      message: 'reposted your product',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:activity],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:unread]
    )

    Activity.insert(
      sender_id: reposter.id,
      receiver_id: reposter.id,
      message: 'reposted a product',
      assoc_type: self.class.name,
      assoc_id: self.id,
      module_type: Activity.module_types[:stream],
      action_type: Activity.action_types[:repost],
      alert_type: Activity.alert_types[:both],
      page_track: page_track,
      status: Activity.statuses[:read]
    )

    if feed
      self.reposted += 1
      self.save
    end

    reposter.followers.each do |follower|
      next if follower.blank?
      next if follower.id == self.merchant_id

      feed = Feed.insert(
        consumer_id: follower.id,
        publisher_id: reposter.id,
        assoc_type: 'ShopProduct',
        assoc_id: self.id,
        feed_type: Feed.feed_types[:repost]
      )

      if feed && follower.enable_alert?
        Activity.insert(
          sender_id: reposter.id,
          receiver_id: follower.id,
          message: 'reposted a product',
          assoc_type: 'ShopProduct',
          assoc_id: self.id,
          module_type: Activity.module_types[:stream],
          action_type: Activity.action_types[:repost_by_following],
          alert_type: Activity.alert_types[:both],
          page_track: page_track,
          status: Activity.statuses[:unread]
        )
      end
    end

    message_body = "#{reposter.display_name} reposted [#{self.name}]"
    PushNotificationWorker.perform_async(
      self.merchant.devices.where(enabled: true).pluck(:token),
      FCMService::push_notification_types[:product_reposted],
      message_body,
      ShopProductSerializer.new(
        self,
        scope: OpenStruct.new(current_user: reposter),
      ).as_json
    )

    true
  end

  def unrepost(unreposter)
    return 'you are trying to un-repost your product' if unreposter.id == self.merchant_id

    Feed.where({
      publisher_id: unreposter.id,
      assoc_type: 'ShopProduct',
      assoc_id: self.id,
      feed_types: Feed.feed_types[:repost]
    }).destroy_all

    true
  end

  def hide(actor)
    return 'You are trying to hide your product' if actor.id == self.merchant_id

    Feed.where({
      publisher_id: actor.id,
      assoc_type: self.class.name,
      assoc_id: self.id
    }).delete_all

    feed = Feed.insert(
      consumer_id: actor.id,
      publisher_id: actor.id,
      assoc_type: self.class.name,
      assoc_id: self.id,
      feed_type: Feed.feed_types[:hide]
    )

    if feed
      Activity.create(
        sender_id: actor.id,
        receiver_id: actor.id,
        message: 'hide a product',
        assoc_type: self.class.name,
        assoc_id: self.id,
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:hide],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:read]
      )
    end

    true
  end

  class << self
    # def explore_query(category, params = {}, user = nil)
    #   query = ShopProduct.includes(:merchant, :category, :variants, :shipments, :covers, :user_products).where(
    #     status: [ShopProduct.statuses[:published], ShopProduct.statuses[:collaborated]],
    #     stock_status: ShopProduct.stock_statuses[:active],
    #     show_status: ShopProduct.show_statuses[:show_all]
    #   )
    #   query = query.joins(:category).where(shop_categories: {is_digital: false})
    #   query = query.where(shop_categories: {name: category}) unless category.eql?('any')
    #   query = query.where.not(merchant_id: user.block_list) if user
    #   query = query.page(params[:page]).order(created_at: :desc).per(params[:per_page])
    # end

    def explore_query(category, params = {}, user = nil)
      where = {
        status: ['published', 'collaborated'],
        stock_status: 'active',
        show_status: 'show_all'
      }
      where[:category_name] = category unless category.blank? || category == 'any'
      if user
        #TODO - blocked_product_ids consider the block_list
        where[:merchant_id] = {} if where[:merchant_id].blank?
        where[:merchant_id][:not] = user.block_list

        where[:id] = {} if where[:id].blank?
        where[:id][:not] = user.blocked_product_ids
      end
      order = {created_at: :desc}
      params = params.merge(per_page: ShopProduct.default_per_page) if params[:per_page].blank?
      params = params.merge(where: where, order: order)
      params = params.merge(includes: [:merchant, :category, :variants, :shipments, :covers, :user_products])
      ShopProduct.search '*', params
    end

    def categories_query(user = nil)
      query = ShopProduct.where(
        status: [ShopProduct.statuses[:published], ShopProduct.statuses[:collaborated]],
        stock_status: ShopProduct.stock_statuses[:active],
        show_status: ShopProduct.show_statuses[:show_all]
      )
      # query = query.joins(:category).where(shop_categories: {is_digital: false})
      query = query.where.not(merchant_id: user.block_list) if user
      category_ids = query.group(:category_id).count.keys
      ShopCategory.where(id: category_ids)
    end
  end
end
