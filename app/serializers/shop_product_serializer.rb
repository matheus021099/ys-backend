class ShopProductSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :price, :reposted, :stock, :sold, :stock_status, :collaborators_count,
    :show_status, :tax_percent, :is_vat, :seller_location, :status, :created_at

  attribute :collaborators, if: :include_collaborators?
  # attribute :creator, if: :include_collaborators?
  attribute :creator_share
  attribute :creator_recoup_cost

  attribute :digital_content_url, if: :include_digital_content?
  attribute :digital_content_name

  # attribute :is_reposted

  belongs_to :merchant
  belongs_to :category

  has_many :variants
  has_many :shipments
  has_many :covers

  def price
    return 0 if object.variants.length == 0
    object.variants[0].price
  end

  # def stock
  #   object.stock
  # end

  def sold
    total = 0
    object.items.ordered.each do |i|
      total += i.quantity
    end
    total
  end

  def collaborators
    user_products = object.user_products.where(users_products: { user_type: UserProduct.user_types[:collaborator] })
    ActiveModel::Serializer::CollectionSerializer.new(
      user_products,
      serializer: UserProductSerializer,
      scope: scope,
      include_user: instance_options[:include_collaborators_user]
    )
  end

  def creator
    user_product = object.user_products.where(users_products: { user_type: UserProduct.user_types[:creator] }).first
    UserProductSerializer.new(
      user_product,
      scope: scope,
      include_user: instance_options[:include_collaborators_user]
    )
  end

  def creator_share
    object.user_products.where(users_products: { user_type: UserProduct.user_types[:creator] }).first.user_share
  end

  def creator_recoup_cost
    object.user_products.where(users_products: { user_type: UserProduct.user_types[:creator] }).first.recoup_cost
  end

  def covers
    object.covers.order(position: :asc)
  end

  def is_reposted
    if scope && scope.current_user
      Feed.where(
        consumer_id: scope.current_user.id,
        publisher_id: scope.current_user.id,
        assoc_type: object.class.name,
        assoc_id: object.id,
        feed_type: Feed.feed_types[:repost]
      ).size > 0
    else
      nil
    end
  end

  def include_collaborators?
    instance_options[:include_collaborators] || false
  end

  def include_digital_content?
    object.category.is_digital &&
    scope && scope.current_user && (
      scope.current_user.id == object.merchant_id ||
      ShopItem.where(
        product_id: object.id,
        customer_id: scope.current_user.id,
        status: ShopItem.statuses[:item_shipped]
      ).count > 0
    )
  end
end
