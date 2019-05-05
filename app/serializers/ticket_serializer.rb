class TicketSerializer < ActiveModel::Serializer
  attributes :id, :reason, :description, :created_at, :closed_at, :status
  attribute :open_user
  attribute :close_user
  attribute :item

  def open_user
    object.open_user.as_json(
      only: [ :id, :slug, :name, :username, :avatar ]
    )
  end

  def close_user
    object.close_user.as_json(
      only: [ :id, :slug, :name, :username, :avatar ]
    )
  end

  def item
    object.item.as_json(
      only: [ :id, :price, :quantity, :fee, :shipping_cost, :tax, :tax_percent, :status, :tracking_site, :tracking_url, :tracking_number ],
      include: {
        product: {
          only: [ :id, :name, :cover ],
        },
        order: {
          only: [ :status, :refund_amount ],
          methods: :external_id
        }
      }
    )
  end
end
