module Api::V1
  class TicketsController < ApiController
    before_action :set_ticket, only: [:show, :update, :destroy]

    swagger_controller :tickets, 'Tickets'

    swagger_api :index do |api|
      param :query, :product_id, :integer, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      product_id = (params[:product_id] || 0).to_i
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 10).to_i

      tickets = policy_scope(Ticket).order('created_at desc').page(page).per(per_page)
      tickets = tickets.where(product_id: product_id) if product_id > 0

      render_success(
        tickets: ActiveModel::SerializableResource.new(tickets),
        pagination: pagination(tickets)
      )
    end


    swagger_api :create do |api|
      summary 'create a ticket'
      param :form, 'ticket[reason]', :string, :required
      param :form, 'ticket[description]', :string, :required
      param :form, 'ticket[item_id]', :integer, :required
    end
    def create
      @ticket = Ticket.new(open_user: current_user)
      authorize @ticket

      item = ShopItem.find(params[:ticket][:item_id]) rescue nil
      render_error 'item is invalid', :unprocessable_entity and return unless item.present?

      @ticket.attributes = permitted_attributes(@ticket)
      @ticket.product_id = item.product_id
      @ticket.order_id = item.order_id

      if @ticket.save
        render_success @ticket
      else
        render_errors @ticket, :unprocessable_entity
      end
    end


    swagger_api :update do |api|
      summary 'update a ticket'
      param :path, :id, :string, :required
      param :form, 'ticket[close_user_id]', :integer, :optional
      param :form, 'ticket[status]', :string, :optional
    end
    def update
      authorize @ticket

      @ticket.attributes = permitted_attributes(@ticket)

      if @ticket.save
        render_success @ticket
      else
        render_errors @ticket, :unprocessable_entity
      end
    end

    private

    def set_ticket
      @ticket = Ticket.find(params[:id])
    end
  end
end
