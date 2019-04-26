class ShopOrderSerializer < ActiveModel::Serializer
  attributes :id, :amount, :fee, :shipping_cost, :tax_cost, :enabled_address, :status, :created_at, :updated_at
  attribute :refund_amount, if: :include_payments?

  belongs_to :customer
  belongs_to :merchant
  belongs_to :billing_address, if: :include_address?
  belongs_to :shipping_address, if: :include_address?
  # belongs_to :payment

  # has_many :payments,  if: :include_payments?
  has_many :items
  # attribute :items
  # def items
  #   ActiveModel::Serializer::CollectionSerializer.new(
  #     object.items,
  #     serializer: ShopItemSerializer,
  #     scope: scope
  #   )
  # end

  def id
    object.external_id
  end

  def refund_amount
    # object.payments.where(payment_type: Payment.payment_types[:refund]).sum(:received_amount)
    object.payments.find_by(payment_type: Payment.payment_types[:buy]).refund_amount rescue 0
  end

  def include_payments?
    instance_options[:include_payments] || false
  end

  def include_address?
    object.merchant_id != scope.current_user.id || object.enabled_address
  end
end