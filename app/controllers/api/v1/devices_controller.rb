module Api::V1
  class DevicesController < ApiController
    swagger_controller :devices, 'device'


    swagger_api :create do |api|
      summary 'create a device'
      param :form, 'device[identifier]', :string, :required, 'device id'
      param :form, 'device[token]', :string, :required, 'fcm token'
      param :form, 'device[platform]', :string, :required, 'ios, android'
    end
    def create
      @device = current_user.devices.find_or_create_by!(identifier: params[:device][:identifier])
      authorize @device
      @device.attributes = permitted_attributes(@device)
      @device.enabled = true
      render_success @device.save
    end
  end
end
