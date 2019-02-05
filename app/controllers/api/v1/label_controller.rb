module Api::V1
  class LabelController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :label, 'related to label feature'

    setup_authorization_header(:label_users)
    swagger_api :label_users do |api|
      summary 'get label users'
      param :query, :status, :string, :optional, 'any, pending, accepted, denied'
    end
    def label_users
      status = params[:status] || 'any'
      relations = Relation.where(context: 'label')
      is_label = current_user.label?

      if is_label
        relations = relations.where(host_id: current_user.id)
      else
        relations = relations.where(client_id: current_user.id)
      end

      if status != 'any'
        relations = relations.where(status: status)
      end

      render json: ActiveModel::Serializer::CollectionSerializer.new(
        relations,
        serializer: RelationSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_host: !is_label,
        include_client: is_label
      )
    end


    setup_authorization_header(:label_albums)
    swagger_api :label_albums do |api|
      summary 'get label albums'
      param :query, :status, :string, :optional, 'any, pending, accepted, denied'
    end
    def label_albums
      status = params[:status] || 'any'
      user_albums = UserAlbum.where(user_type: UserAlbum.user_types[:label])
      is_label = current_user.label?

      if is_label
        user_albums = user_albums.where(user_id: current_user.id)
      else
        user_albums = user_albums.joins(:album).where(albums: {user_id: current_user.id})
      end

      if status != 'any'
        user_albums = user_albums.where(status: status)
      end

      render json: ActiveModel::Serializer::CollectionSerializer.new(
        user_albums,
        serializer: UserAlbumSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_user: !is_label,
        # include_user: true,
        include_album: true,
      )
    end

  end
end