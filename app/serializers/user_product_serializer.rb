class UserProductSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :product_id, :user_type, :user_share, :status

  belongs_to :user, if: :include_user?
  belongs_to :product, if: :include_product?

  def include_user?
    instance_options[:include_user] || false
  end

  def include_product?
    instance_options[:include_product] || false
  end
end