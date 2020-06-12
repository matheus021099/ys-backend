class Util::Serializer
  class << self
    def polymophic_serializer(assoc)
      return {} if assoc.blank?

      return case assoc.class.name
        when 'Album'
          assoc.as_json(
            only: [ :id, :slug, :name, :cover, :album_type ]
          )
        when 'ShopProduct'
          assoc.as_json(
            only: [ :id, :name ],
            include: {
              covers: {
                only: [ :id, :cover, :position ]
              }
            }
          )
        when 'User'
          assoc.as_json(
            only: [ :id, :slug, :display_name, :avatar, :user_type ]
          )
        when 'Post'
          assoc.as_json(
            only: [ :id, :cover, :media_name ]
          )
      end
    end
  end
end
