class PostSerializer < ActiveModel::Serializer
  attributes :id, :media_type, :media_name, :media_url, :cover, :description, :played, :assoc_type, :assoc_selector

  attribute :assoc
  attribute :user

  def user
    object.user.as_json(only: [ :id, :slug, :username, :display_name, :user_type, :avatar ])
  end

  def assoc
    case object.assoc_type
      when 'Album'
        object.assoc.as_json(
          only: [ :id, :slug, :name, :cover, :album_type ],
          include: {
            user: {
              only: [ :id, :slug, :name, :avatar ]
            }
          }
        )
      when 'ShopProduct'
        object.assoc.as_json(
          only: [ :id, :name, :cover ],
          include: {
            merchant: {
              only: [ :id, :slug, :name, :avatar ]
            }
          }
        )
    end
  end
end
