module Api::V1
  class PaymentsController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :payments, 'Payments'


    swagger_api :index do |api|
      summary 'list payments'
      param :query, :q, :string, :optional
      param :query, :payment_types, :string, :optional, 'any, refund'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      render_error "Not authorized" and return unless current_user.admin?
      payment_types = params[:payment_types].present? ? params[:payment_types].split(',').map(&:strip) : ['any']
      payments = Payment
        .joins("LEFT JOIN users sender ON sender.id = payments.sender_id")
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)
        # .order("created_at DESC")
      payments = payments.where("sender.display_name ILIKE ?", "#{params[:q]}%") unless params[:q].blank?
      payments = payments.where(payment_type: payment_types) unless payment_types.include?('any')
      render_success(
        payments: ActiveModel::Serializer::CollectionSerializer.new(
          payments,
          serializer: PaymentSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(payments)
      )
    end


    swagger_api :has_transaction_in_period do |api|
      summary 'check if has a transaction within 30 days'
      param :header, 'Authorization', :string, :optional, 'Authorization token'
    end
    def has_transaction_in_period
      render_success Payment.sent_from(current_user.id).where("created_at < ?", 1.month.ago).size > 0
    end


    setup_authorization_header(:sent)
    swagger_api :sent do |api|
      summary 'sent payments'
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def sent
      payments = Payment.sent_from(current_user.id)
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)
      render_success(
        payments: ActiveModel::Serializer::CollectionSerializer.new(
          payments,
          serializer: PaymentSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(payments)
      )
    end


    setup_authorization_header(:received)
    swagger_api :received do |api|
      summary 'received payments'
    end
    def received
      payments = Payment.received_by(current_user.id)
        .page(params[:page] || 1)
        .per(params[:per_page] || 10)
      render_success(
        payments: ActiveModel::Serializer::CollectionSerializer.new(
          payments,
          serializer: PaymentSerializer,
          scope: OpenStruct.new(current_user: current_user)
        ),
        pagination: pagination(payments)
      )
    end


    setup_authorization_header(:refund)
    swagger_api :refund do |api|
      summary 'refund on the specific payment'
      param :path, :id, :string, :required
      param :form, :amount, :integer, :required
      param :form, :description, :string, :optional
    end
    def refund
      @payment = Payment.includes(:sender, :receiver).find(params[:id])
      render_error("Cannot refund", :unprocessable_entity) and return if @payment.receiver_id != current_user.id || !@payment.pay_view_stream?

      amount = params[:amount].to_i rescue 0
      description = params[:description] || ''

      _payment = Payment.refund_without_fee(
        payment: @payment,
        amount: amount,
        description: description
      )
      # case @payment.payment_type
      #   when 'pay_view_stream'
      #     _payment = Payment.refund_without_fee(
      #       payment: @payment,
      #       amount: amount,
      #       description: description
      #     )
      #   else
      #     _payment = Payment.refund_order(
      #       payment: @payment,
      #       amount: amount,
      #       description: description
      #     )
      # end
      render_error(_payment, :unprocessable_entity) and return unless _payment.instance_of? Payment

      current_user.reload
      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end


    setup_authorization_header(:refund_order)
    swagger_api :refund_order do |api|
      summary 'refund on the order payment'
      param :path, :id, :string, :required
      param :form, :amount, :integer, :required
      param :form, :description, :string, :optional
      param :form, :items, :string, :optional
    end
    def refund_order
      @payment = Payment.includes(:sender, :receiver).find(params[:id])
      render_error("Cannot refund an order", :unprocessable_entity) and return unless @payment.receiver_id == current_user.id && @payment.buy?
      items = JSON.parse(params[:items]) rescue nil
      render_error("Cannot parse the items", :unprocessable_entity) and return if items.blank? || items.size == 0

      amount = params[:amount].to_i rescue 0
      description = params[:description] || ''

      _payment = Payment.refund_order(
        payment: @payment,
        amount: amount,
        description: description,
        items: items
      )
      render_error(_payment, :unprocessable_entity) and return unless _payment.instance_of? Payment

      current_user.reload
      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end


    setup_authorization_header(:deposit)
    swagger_api :deposit do |api|
      summary 'deposit'
      param :form, :payment_token, :string, :required
      param :form, :amount, :integer, :required
    end
    def deposit
      _payment = Payment.stream_deposit(
        sender: current_user,
        payment_token: params[:payment_token],
        sent_amount: params[:amount].to_i
      )
      render_error _payment, :unprocessable_entity and return unless _payment.instance_of? Payment
      # render json: current_user,
      #   serializer: UserSerializer,
      #   scope: OpenStruct.new(current_user: current_user),
      #   include_all: true
      render_success true
    end


    setup_authorization_header(:withdraw)
    swagger_api :withdraw do |api|
      summary 'withdraw'
      param :form, :amount, :integer, :required
    end
    def withdraw
      payment = Payment.withdraw(
        user_id: current_user.id,
        amount: params[:amount].to_i
      )
      # render_error('Failed in withdraw', :unprocessable_entity) and return unless payment.instance_of? Payment
      render_error(payment, :unprocessable_entity) and return unless payment.instance_of? Payment

      current_user.reload
      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end
  end
end
