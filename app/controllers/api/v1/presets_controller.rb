module Api::V1
  class PresetsController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    before_action :set_preset, only: [:destroy, :load]

    swagger_controller :presets, 'presets'

    setup_authorization_header(:index)
    swagger_api :index do |api|
      summary 'get presets'
      param :query, :context, :string, :required, 'hidden_genre, stream_guest, etc'
    end
    def index
      presets = Preset.where(user_id: current_user.id)
      render json: presets.as_json(only: [:id, :user_id, :context, :name, :data])
    end


    swagger_api :create do |api|
      summary 'create a preset'
      param :form, :name, :string, :required
    end
    def create
      Preset.create(
        user_id: current_user.id,
        context: Preset.preset_contexts[:hidden_genre],
        name: params[:name],
        data: current_user.genre_list
      )

      presets = Preset.where(user_id: current_user.id)
      render json: presets.as_json(only: [:id, :user_id, :context, :name, :data])
    end


    swagger_api :load do |api|
      summary 'load a preset'
      param :path, :id, :string, :required
    end
    def load
      current_user.genre_list = @preset.data
      current_user.save

      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end


    swagger_api :destroy do |api|
      summary 'remove a preset'
      param :path, :id, :string, :required
    end
    def destroy
      @preset.destroy
      render_success true
    end

    private

    def set_preset
      # @preset = Preset.find(params[:id])
      @preset = Preset.where(
        user_id: current_user.id,
        id: params[:id]
      ).first
    end
  end
end
