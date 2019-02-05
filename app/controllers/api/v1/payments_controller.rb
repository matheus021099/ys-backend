module Api::V1
  class PaymentsController < ApiController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    swagger_controller :payments, 'Payments'


    swagger_api :index do |api|
      summary 'list payments'
    end
    def index
      render_success true
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
      render_error("Can't refund", :unprocessable_entity) and return unless @payment.receiver_id == current_user.id && @payment.buy?

      amount = params[:amount].to_i rescue 0
      description = params[:description] || ''

      _payment = Payment.refund(
        payment: @payment,
        amount: amount,
        description: description
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
      stripe_charge_id = Payment.deposit(
        user: current_user,
        payment_token: params[:payment_token],
        amount: params[:amount].to_i
      )
      render_error('Failed in deposit', :unprocessable_entity) and return if stripe_charge_id === false

      current_user.reload
      render json: current_user,
        serializer: UserSerializer,
        scope: OpenStruct.new(current_user: current_user),
        include_all: true
    end


    setup_authorization_header(:withdraw)
    swagger_api :withdraw do |api|
      summary 'withdraw'
      param :form, :amount, :integer, :required
    end
    def withdraw
      payment = Payment.withdraw(
        user_id: current_user.id,
        amount: params[:amount]
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
