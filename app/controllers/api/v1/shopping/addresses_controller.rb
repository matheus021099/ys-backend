module Api::V1::Shopping
  class AddressesController < ApiController
    swagger_controller :addresses, 'Addresses'

    before_action :set_address, only: [ :update, :destroy ]

    swagger_api :index do |api|
      summary 'get items in the cart'
    end
    def index
      skip_policy_scope
      addresses = current_user.addresses
      render json: ActiveModel::Serializer::CollectionSerializer.new(addresses, serializer: ShopAddressSerializer)
    end


    swagger_api :create do |api|
      summary 'create a address'
      param :form, 'shop_address[first_name]', :string, :optional
      param :form, 'shop_address[last_name]', :string, :optional
      param :form, 'shop_address[unit]', :string, :optional
      param :form, 'shop_address[street_1]', :string, :optional
      param :form, 'shop_address[street_2]', :string, :optional
      param :form, 'shop_address[city]', :string, :optional
      param :form, 'shop_address[state]', :string, :optional
      param :form, 'shop_address[country]', :string, :optional
      param :form, 'shop_address[postcode]', :string, :optional
      param :form, 'shop_address[phone_number]', :string, :optional
      param :form, 'shop_address[set_default]', :integer, :optional
    end
    def create
      @address = ShopAddress.new(customer_id: current_user.id)
      authorize @address
      @address.attributes = permitted_attributes(@address)
      if @address.save
        if params[:shop_address][:set_default]
          current_user.default_address = @address
          current_user.save
        end

        # render_success ActiveModel::Serializer::ShopAddressSerializer.new(@address)
        render_success @address
      else
        render_errors @address, :unprocessable_entity
      end
    end


    swagger_api :update do |api|
      summary 'update an address'
      param :path, :id, :string, :required
      param :form, 'shop_address[first_name]', :string, :optional
      param :form, 'shop_address[last_name]', :string, :optional
      param :form, 'shop_address[unit]', :string, :optional
      param :form, 'shop_address[street_1]', :string, :optional
      param :form, 'shop_address[street_2]', :string, :optional
      param :form, 'shop_address[city]', :string, :optional
      param :form, 'shop_address[state]', :string, :optional
      param :form, 'shop_address[country]', :string, :optional
      param :form, 'shop_address[postcode]', :string, :optional
      param :form, 'shop_address[phone_number]', :string, :optional
      param :form, 'shop_address[set_default]', :integer, :optional
    end
    def update
      is_referred = @address.referred?

      authorize @address
      @address.attributes = permitted_attributes(@address)

      if is_referred
        address_attributes = @address.attributes
        @address = ShopAddress.new(customer_id: current_user.id)
        @address.attributes = address_attributes.except('id')
      end

      if @address.save
        if params[:shop_address][:set_default]
          current_user.default_address = @address
          current_user.save
        end
      end

      # render_success ActiveModel::Serializer::ShopAddressSerializer.new(@address)
      render_success @address
    end


    swagger_api :destroy do |api|
      summary 'delete an address'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @address
      @address.remove
      render_success(true)
    end

    private
    def set_address
      @address = ShopAddress.find(params[:id])
    end

  end
end
