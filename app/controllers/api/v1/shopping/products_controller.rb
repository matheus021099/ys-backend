module Api::V1::Shopping
  class ProductsController < ApiController
    before_action :set_product, only: [
      :show, :update, :destroy, :release, :repost, :hide,
      :accept_collaboration, :deny_collaboration,
      :ordered_items, :tickets
    ]
    skip_before_action :authenticate_token!, only: [:show]
    before_action :authenticate_token, only: [:show]

    swagger_controller :products, 'Product'

    swagger_api :index do |api|
      summary 'get products - used in sell / products'
      param :query, :statuses, :string, :optional, 'any, published, privated, pending, collaboration'
      param :query, :stock_statuses, :string, :optional, 'any, inactive, active, hidden, sold_out, coming_soon'
      param :query, :user_statuses, :string, :optional, 'any, accepted, denied, pending'
    end
    def index
      skip_policy_scope
      statuses = params[:statuses].present? ? params[:statuses].split(',').map(&:strip) : ['any']
      stock_statuses = params[:stock_statuses].present? ? params[:stock_statuses].split(',').map(&:strip) : ['any']
      user_statuses = params[:user_statuses].present? ? params[:user_statuses].split(',').map(&:strip) : ['any']

      products = ShopProduct.includes(:merchant, :category, :variants, :shipments, :covers).joins(:user_products)
        .where(users_products: { user_id: current_user.id })
        .where.not(status: ShopProduct.statuses[:deleted])
        .order(created_at: :desc)
      products = products.where(users_products: { status: user_statuses }) unless user_statuses.include?('any')
      products = products.where(stock_status: stock_statuses) unless stock_statuses.include?('any')
      products = products.where(status: statuses) unless statuses.include?('any')

      # render_success ActiveModelSerializers::SerializableResource.new(
      #   products,
      #   each_serializer: ShopProductSerializer,
      #   scope: OpenStruct.new(current_user: current_user),
      #   include_collaborators: true,
      #   include_collaborators_user: true,
      # )
      render_success ActiveModel::Serializer::CollectionSerializer.new(
        products,
        serializer: ShopProductSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_collaborators: true,
        include_collaborators_user: true,
      )
    end


    setup_authorization_header(:search)
    swagger_api :search do |api|
      summary 'search products'
      param :query, :q, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def search
      skip_policy_scope

      q = params[:q] || '*'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i
      orders = {}

      # products = policy_scope(ShopProduct).page(page).per(per_page)
      products = ShopProduct.search(
        q,
        fields: [:name, :description, :merchant_username, :merchant_display_name],
        match: :word_start,
        where: {
          id: {not: current_user.id},
          status: ['published', 'collaborated'],
          stock_status: 'active',
          show_status: 'show_all'
        },
        includes: [:merchant, :category, :variants, :shipments, :covers, :user_products],
        order: orders,
        limit: per_page,
        offset: (page - 1) * per_page
      )

      render_success(
        products: ActiveModelSerializers::SerializableResource.new(
          products,
          each_serializer: ShopProductSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(products)
      )
    end


    swagger_api :show do |api|
      summary 'get a product'
      param :path, :id, :string, :required, 'product id'
    end
    def show
      authorize @product
      render json:
        @product,
        serializer: ShopProductSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_collaborators: true,
        include_collaborators_user: true
    end


    swagger_api :create do |api|
      summary 'create a product'
      param :form, 'shop_product[name]', :string, :required
      param :form, 'shop_product[description]', :string, :required
      param :form, 'shop_product[stock_status]', :string, :required
      param :form, 'shop_product[category_id]', :string, :required
      param :form, 'shop_product[price]', :integer, :required
      param :form, 'shop_product[show_status]', :string, :required
      param :form, 'shop_product[variants]', :string, :required
      param :form, 'shop_product[shipments]', :string, :required
      param :form, 'shop_product[cover1]', :File, :optional
      param :form, 'shop_product[cover2]', :File, :optional
      param :form, 'shop_product[cover3]', :File, :optional
      param :form, 'shop_product[collaborators]', :string, :optional, 'refer update API, e.g. [{user_id: "xxx", user_role: "Artist"}]'
      param :form, 'shop_product[creator_recoup_cost]', :integer, :optional
      param :form, 'shop_product[tax_percent]', :float, :optional
      param :form, 'shop_product[is_vat]', :boolean, :optional
      param :form, 'shop_product[seller_location]', :string, :optional
      param :form, 'shop_product[digital_content]', :File, :optional
      param :form, 'shop_product[digital_content_name]', :string, :optional
    end
    def create
      @product = ShopProduct.new(merchant: current_user, status: ShopProduct.statuses[:pending])
      authorize @product
      product_attributes = permitted_attributes(@product)
      variants = JSON.parse(params[:shop_product][:variants])
      variants.each do |variant|
        @product.variants.build(variant)
      end
      shipments = JSON.parse(params[:shop_product][:shipments])
      shipments.each do |shipment|
        @product.shipments.build(shipment)
      end
      3.times do
        @product.covers.build
      end
      @product.covers.first.position = 0
      @product.covers.first.cover = params[:shop_product][:cover1]
      @product.covers.second.position = 1
      @product.covers.second.cover = params[:shop_product][:cover2]
      @product.covers.third.position = 2
      @product.covers.third.cover = params[:shop_product][:cover3]
      @product.attributes = product_attributes

      @product.digital_content = params[:shop_product][:digital_content]

      collaborators_count = 0
      obj = {}
      collaborators = []
      collaborator = nil
      unless params[:shop_product][:collaborators].blank?
        begin
          data = JSON.parse(params[:shop_product][:collaborators])
          obj = data.inject({}){|o, c| o[c['user_id']] = c; o}
          collaborators = User.where(id: obj.keys)
          collaborators_count = collaborators.size
          @product.collaborators_count = collaborators_count
        rescue => ex
        end
      end

      total_collaborators_share = 0
      collaborators.each do |collaborator|
        total_collaborators_share += obj[collaborator.id]['user_share']
      end
      creator_share = 100 - total_collaborators_share
      creator_recoup_cost = (params[:shop_product][:creator_recoup_cost] || 0).to_i
      creator_recoup_cost = 0 if creator_recoup_cost < 0
      render_error 'Total share shoud be less than 100', :unprocessable_entity and return if creator_share <= 0
      render_error 'Recoup cost should never be more than total cost of items', :unprocessable_entity and return if creator_recoup_cost > @product.variants.inject(0){|s, v| s += v.price * (v.quantity || 0)}

      if @product.save
        UserProduct.create(
          user_id: current_user.id,
          product_id: @product.id,
          user_type: UserProduct.user_types[:creator],
          user_share: creator_share,
          recoup_cost: creator_recoup_cost,
          status: UserProduct.statuses[:accepted]
        )

        message_body = "#{current_user.display_name} wants to upload this product collaboration"
        collaborators.each do |collaborator|
          UserProduct.create(
            user_id: collaborator.id,
            product_id: @product.id,
            user_type: UserProduct.user_types[:collaborator],
            user_share: obj[collaborator.id]['user_share'],
            status: UserProduct.statuses[:pending]
          )

          attachment = Attachment.new(
            attachment_type: Attachment.attachment_types[:collaboration],
            attachable_type: @product.class.name,
            attachable_id: @product.id,
            repost_price: 0,
            payment_customer_id: nil,
            payment_token: nil,
            status: Attachment.statuses[:pending]
          )
          receipt = Util::Message.send(current_user, collaborator, message_body, nil, attachment)
        end

        @product.release
      end

      render json: @product,
        serializer: ShopProductSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    swagger_api :update do |api|
      summary 'update a product'
      param :path, :id, :string, :required
      param :form, 'shop_product[name]', :string, :optional
      param :form, 'shop_product[description]', :string, :optional
      param :form, 'shop_product[stock_status]', :string, :optional
      param :form, 'shop_product[category_id]', :string, :optional
      param :form, 'shop_product[price]', :integer, :optional
      param :form, 'shop_product[show_status]', :string, :optional
      param :form, 'shop_product[variants]', :string, :optional
      param :form, 'shop_product[shipments]', :string, :optional
      param :form, 'shop_product[cover1]', :File, :optional
      param :form, 'shop_product[cover2]', :File, :optional
      param :form, 'shop_product[cover3]', :File, :optional
      param :form, 'shop_product[collaborators]', :string, :optional, 'e.g. [{id: "xxx", user_id: "xxx", user_role: "Artist", status: "accepted"}]'
      param :form, 'shop_product[creator_recoup_cost]', :integer, :optional
      param :form, 'shop_product[tax_percent]', :float, :optional
      param :form, 'shop_product[is_vat]', :boolean, :optional
      param :form, 'shop_product[seller_location]', :string, :optional
      param :form, 'shop_product[digital_content]', :File, :optional
      param :form, 'shop_product[digital_content_name]', :string, :optional
    end
    def update
      authorize @product
      product_attributes = permitted_attributes(@product)
      if params[:shop_product][:cover1].present?
        if params[:shop_product][:cover1].instance_of? ActionDispatch::Http::UploadedFile
          @product.covers.first.update_attributes(cover: params[:shop_product][:cover1])
        else
          cover = @product.covers.first
          cover.remove_cover!
          cover.position = 0
          cover.save!
        end
      end
      if params[:shop_product][:cover2].present?
        if params[:shop_product][:cover2].instance_of? ActionDispatch::Http::UploadedFile
          @product.covers.second.update_attributes(cover: params[:shop_product][:cover2])
        else
          cover = @product.covers.second
          cover.remove_cover!
          cover.position = 1
          cover.save!
        end
      end
      if params[:shop_product][:cover3].present?
        if params[:shop_product][:cover3].instance_of? ActionDispatch::Http::UploadedFile
          @product.covers.third.update_attributes(cover: params[:shop_product][:cover3])
        else
          cover = @product.covers.third
          cover.remove_cover!
          cover.position = 2
          cover.save!
        end
      end

      if params[:shop_product][:digital_content].present?
        if params[:shop_product][:digital_content].instance_of? ActionDispatch::Http::UploadedFile
          @product.digital_content = params[:shop_product][:digital_content]
        else
          @product.remove_digital_content!
        end
      end
      @product.attributes = product_attributes
      @product.save

      unless params[:shop_product][:variants].blank?
        ShopProductVariant.where(product_id: @product.id).delete_all
        variants = JSON.parse(params[:shop_product][:variants])
        variants.each do |variant|
          ShopProductVariant.create(variant.merge(product_id: @product.id))
        end
      end

      unless params[:shop_product][:shipments].blank?
        ShopProductShipment.where(product_id: @product.id).delete_all
        shipments = JSON.parse(params[:shop_product][:shipments])
        shipments.each do |shipment|
          ShopProductShipment.create(shipment.merge(product_id: @product.id))
        end
      end

      collaborators_count = 0
      obj = {}
      collaborators = []
      collaborator = nil
      unless params[:shop_product][:collaborators].blank?
        begin
          data = JSON.parse(params[:shop_product][:collaborators])
          obj = data.inject({}){|o, c| o[c['user_id']] = c; o}
          collaborators = User.where(id: obj.keys)
          collaborators_count = collaborators.size
          @product.collaborators_count = collaborators_count
        rescue => ex
        end
      end

      total_collaborators_share = 0
      collaborators.each do |collaborator|
        total_collaborators_share += obj[collaborator.id]['user_share']
      end
      creator_share = 100 - total_collaborators_share
      creator_recoup_cost = (params[:shop_product][:creator_recoup_cost] || 0).to_i
      creator_recoup_cost = 0 if creator_recoup_cost < 0
      render_error 'Total share shoud be less than 100', :unprocessable_entity and return if creator_share <= 0
      render_error 'Recoup cost should never be more than total cost of items', :unprocessable_entity and return if @product.pending? && @product.digital_content.blank? && creator_recoup_cost > @product.variants.inject(0){|s, v| s += v.price * (v.quantity || 1) }
      # puts "\n\n"
      # p @product.collaborators_count
      # p total_collaborators_share
      # p obj
      # puts "\n\n\n"

      if @product.save
        unless params[:shop_product][:collaborators].blank?
          ActiveRecord::Base.transaction do
            UserProduct.where(product_id: @product.id, user_type: UserProduct.user_types[:creator]).update_all(user_share: creator_share, recoup_cost: creator_recoup_cost)
            UserProduct.includes(:user).where(product_id: @product.id, user_type: UserProduct.user_types[:collaborator]).each do |up|
              next if obj.keys.include?(up.user.id)

              attachment = Attachment.find_by_status(
                sender: @product.merchant,
                receiver: up.user,
                attachment_type: Attachment.attachment_types[:collaboration],
                attachable: @product
              )
              if attachment.present?
                message_body = "#{current_user.display_name} canceled this product collaboration"
                attachment.message.update_attributes(body: message_body)
                attachment.update_attributes(status: Attachment.statuses[:canceled])
              end
            end
            UserProduct.where(product_id: @product.id, user_type: UserProduct.user_types[:collaborator]).delete_all

            message_body = "#{current_user.display_name} wants to upload this product collaboration"
            collaborators.each do |collaborator|
              obj[collaborator.id].delete('user')
              UserProduct.create(
                obj[collaborator.id].merge(
                  product_id: @product.id,
                  user_type: UserProduct.user_types[:collaborator]
                )
              )

              if obj[collaborator.id]['id'].blank?
                ### e.g. collaborated with A -> B -> A
                attachment = Attachment.find_by_status(
                  sender: @product.merchant,
                  receiver: collaborator,
                  attachment_type: Attachment.attachment_types[:collaboration],
                  attachable: @product
                )

                if attachment.present?
                  attachment.message.update_attributes(body: message_body)
                  attachment.update_attributes(status: Attachment.statuses[:pending])
                else
                  attachment = Attachment.new(
                    attachment_type: Attachment.attachment_types[:collaboration],
                    attachable_type: @product.class.name,
                    attachable_id: @product.id,
                    repost_price: 0,
                    payment_customer_id: nil,
                    payment_token: nil,
                    status: Attachment.statuses[:pending]
                  )
                  receipt = Util::Message.send(current_user, collaborator, message_body, nil, attachment)
                end
              end

            end
          end
        end

        @product.release
      end

      render json: @product,
        serializer: ShopProductSerializer,
        scope: OpenStruct.new(current_user: current_user)
    end


    swagger_api :destroy do |api|
      summary 'delete a product'
      param :path, :id, :string, :required
    end
    def destroy
      authorize @product
      @product.remove
      render_success(true)
    end


    setup_authorization_header(:release)
    swagger_api :release do |api|
      summary 'release a product'
      param :path, :id, :string, :required
    end
    def release
      authorize @product
      @product.release
      render_success(true)
    end


    setup_authorization_header(:repost)
    swagger_api :repost do |api|
      summary 'repost a product'
      param :path, :id, :string, :required
      param :query, :page_track, :string, :optional, 'from which page repost has happend'
    end
    def repost
      authorize @product rescue render_error "You can't repost your own product", :unprocessable_entity and return
      @product.repost(current_user, params[:page_track])
      render_success(true)
    end


    setup_authorization_header(:unrepost)
    swagger_api :unrepost do |api|
      summary 'unrepost a product'
      param :path, :id, :string, :required
    end
    def unrepost
      authorize @product
      @product.unrepost
      render_success(true)
    end


    setup_authorization_header(:hide)
    swagger_api :hide do |api|
      summary 'hide an product'
      param :path, :id, :string, :required
    end
    def hide
      authorize @product
      @product.hide(current_user)
      render_success(true)
    end


    setup_authorization_header(:accept_collaboration)
    swagger_api :accept_collaboration do |api|
      summary 'accept collaboration on a product'
      param :path, :id, :string, :required
    end
    def accept_collaboration
      authorize @product

      user_product = UserProduct.find_by(
        user_id: current_user.id,
        product_id: @product.id,
        user_type: UserProduct.user_types[:collaborator],
        status: UserProduct.statuses[:pending]
      )
      user_product.update_attributes(status: UserProduct.statuses[:accepted]) if user_product.present?

      attachment = Attachment.find_pending(
        sender: @product.merchant,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:collaboration],
        attachable: @product
      )
      if attachment.present?
        message_body = "#{current_user.display_name} accepted this collaboration.<br>Use the web/desktop to release this product."
        attachment.update_attributes(status: Attachment.statuses[:accepted])
        attachment.message.update_attributes(body: message_body)
        attachment.message.mark_as_unread(@product.merchant)
        # receipt = attachment.message.receipt_for(@product.merchant).first
        # receipt.update_attributes(is_read: false) if receipt
      end

      render_success true
    end


    setup_authorization_header(:deny_collaboration)
    swagger_api :deny_collaboration do |api|
      summary 'deny collaboration on a product'
      param :path, :id, :string, :required
    end
    def deny_collaboration
      authorize @product

      user_product = UserProduct.find_by(
        user_id: current_user.id,
        product_id: @product.id,
        user_type: UserProduct.user_types[:collaborator],
        status: UserProduct.statuses[:pending]
      )
      user_product.update_attributes(status: UserProduct.statuses[:denied]) if user_product.present?

      attachment = Attachment.find_pending(
        sender: @product.merchant,
        receiver: current_user,
        attachment_type: Attachment.attachment_types[:collaboration],
        attachable: @product
      )
      attachment.update_attributes(status: Attachment.statuses[:denied]) if attachment.present?

      render_success true
    end


    setup_authorization_header(:ordered_items)
    swagger_api :ordered_items do |api|
      summary 'ordered items on the product'
      param :path, :id, :string, :required
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def ordered_items
      authorize @product

      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      items = @product.items.includes(order: [:customer, :shipping_address]).where.not(
        status: ShopItem.statuses[:item_not_ordered]).order('created_at desc'
      ).page(page).per(per_page)

      render_success(
        items: items.as_json(
          only: [ :id, :price, :quantity, :fee, :shipping_cost, :tax, :tax_percent, :status ],
          include: {
            order: {
              only: [ :amount, :fee, :shipping_cost, :tax_cost, :status, :created_at ],
              methods: :external_id,
              include: {
                customer: {
                  only: [ :id, :slug, :name, :username, :avatar ]
                },
                shipping_address: {}
              }
            }
          }
        ),
        pagination: pagination(items)
      )
    end


    setup_authorization_header(:tickets)
    swagger_api :tickets do |api|
      summary 'tickets on the product'
      param :path, :id, :string, :required
      param :query, :status, :string, :optional, 'any, open, close'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def tickets
      authorize @product

      status = params[:status] || 'any'
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      tickets = Ticket.includes(:open_user, :close_user, item: [:product, :order]).where(product_id: @product.id).order('created_at desc').page(page).per(per_page)
      tickets = tickets.where(status: status) unless status.eql?('any')

      render_success(
        tickets: ActiveModel::SerializableResource.new(tickets),
        pagination: pagination(tickets)
      )
    end


    private

    def set_product
      @product = ShopProduct.includes(:merchant, :category, :variants, :shipments, :covers, :user_products).find(params[:id])
    end
  end
end
