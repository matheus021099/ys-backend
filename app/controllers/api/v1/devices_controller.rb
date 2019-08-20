module Api::V1
  class DevicesController < ApiController
    swagger_controller :devices, 'device'


    setup_authorization_header(:create)
    swagger_api :create do |api|
      summary 'create a device'
      param :form, 'device[token]', :string, :required, 'device token'
      param :form, 'device[platform]', :string, :required, 'ios, android'
    end
    def create
      @device = Device.new(user: current_user)
      authorize @device
      @device.attributes = permitted_attributes(@device)
      @device.enabled = true
      render_success @device.save
    end
  end
end
