class PostSerializer < ActiveModel::Serializer
  attributes :id, :media_type, :media_name, :media_url, :cover, :description, :played,
    :assoc_type, :assoc_selector, :created_at
  attribute :commented

  attribute :assoc
  attribute :user

  def commented
    object.comments.size
  end

  def user
    object.user.as_json(
      only: [ :id, :slug, :username, :display_name, :user_type, :avatar, :status ],
      methods: :stripe_connected
    )
  end

  def assoc
    case object.assoc_type
      when 'Album'
        object.assoc.as_json(
          only: [ :id, :slug, :name, :cover, :album_type ],
          include: {
            user: {
              only: [ :id, :slug, :username, :display_name, :user_type, :avatar, :status ]
            }
          }
        )
      when 'ShopProduct'
        object.assoc.as_json(
          only: [ :id, :name ],
          # methods: :covers,
          include: {
            covers: {
              only: [ :id, :cover, :position ]
            },
            merchant: {
              only: [ :id, :slug, :username, :display_name, :user_type, :avatar, :status ]
            }
          }
        )
    end
  end
end
