module Api::V1
  class ConversationsController < ApiController
    swagger_controller :comments, 'Comments'

    before_action :set_conversation, only: [:update, :destroy]


    swagger_api :index do |api|
      summary 'list all conversations'
    end
    def index
      conversations = current_user.mailbox.conversations
      render_success(conversations)
    end


    swagger_api :create do |api|
      param :form, 'message[body]', :string, :required
      param :form, 'message[receiver_id]', :string, :required
      param :form, 'message[attachable_type]', :File, :optional
      param :form, 'message[attachable_id]', :string, :optional
      param :form, 'payment_token', :string, :optional
    end
    def create
    end


    swagger_api :show do |api|
      conversation = get_conversation(sender, receiver)
    end
    def show
    end

    private
    def set_conversation
      @conversation = Conversation
    end
  end
end
