module Api::V1
  class SettingsController < ApiController
    skip_before_action :authenticate_token!, only: [:index]
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :settings, 'Settings'

    swagger_api :index do |api|
      summary 'list settings'
    end
    def index
      settings = Setting.all.inject(Setting::OPTIONS.clone){|obj, r| obj[r[:key].to_sym] = r[:value]; obj;}
      render json: {
        disable_sign_up: ActiveModel::Type::Boolean.new.cast(settings[:disable_sign_up]),
        disable_live_video: ActiveModel::Type::Boolean.new.cast(settings[:disable_live_video]),
        disable_merch_upload: ActiveModel::Type::Boolean.new.cast(settings[:disable_merch_upload]),
        audio_reminder_tracks_count: settings[:audio_reminder_tracks_count].to_i
      }
    end


    setup_authorization_header(:create)
    swagger_api :create do |api|
      summary 'create/update a setting'
      param :form, :key, :string, :required
      param :form, :value, :string, :required
    end
    def create
      render_error 'Permission denied', :unauthorized and return unless current_user.admin?
      render_error 'Please enter key and value', :unprocessable_entity and return unless params[:key].present? && params[:value].present?
      render_error 'Invalid key', :unprocessable_entity and return unless Setting::OPTIONS.keys.include?(params[:key].to_sym)
      setting = Setting.find_or_create_by(key: params[:key])
      setting.update_attributes(value: params[:value]) if params[:value].present?
      render_success true
    end
  end
end