class PaymentSerializer < ActiveModel::Serializer
  attributes :id, :payment_type, :description, :payment_token,
    :sent_amount, :received_amount, :refund_amount,
    :fee, :user_share, :status, :created_at, :order_id
  attribute :assoc # it responds json data
  # belongs_to :assoc # it responds data using serializer

  belongs_to :sender
  belongs_to :receiver

  def order_id
    Util::Number.encode object.order_id unless object.order_id.blank?
  end

  def assoc
    return nil unless object.assoc

    case object.payment_type
      when 'collaborate'
        ShopProductSerializer.new(object.assoc, scope: scope, include_collaborators: true, include_collaborators_user: true)
      else
        nil
    end
  end
end
