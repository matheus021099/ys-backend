module Api::V1
  class MessagesController < ApiController
    swagger_controller :messages, 'Message Management'

    # after_action :verify_authorized, except: [:conversations]
    # before_action :set_message, only: [:update, :destroy, :accept_repost]
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_user, only: [:index, :conversations]

    swagger_api :index do |api|
      summary 'get messages by a conversation'
      param :query, :conversation_id, :string, :required
      param :query, :user_id, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def index
      @conversation = @user.mailbox.conversations.find(params[:conversation_id])
      @conversation.mark_as_read(current_user)

      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 50).to_i

      messages = Mailboxer::Notification.joins(:receipts).where(
        conversation_id: @conversation.id
      ).page(page).per(per_page).order(updated_at: :desc)

      if current_user.admin? || (current_user.moderator? && current_user.enabled_view_direct_messages)
        messages = messages.where(
          mailboxer_receipts: {
            receiver_id: @user.id
          }
        )
      else
        messages = messages.where(
          mailboxer_receipts: {
            receiver_id: @user.id,
            deleted: false
          }
        )
      end

      render_success(
        messages: ActiveModelSerializers::SerializableResource.new(
          messages,
          each_serializer: MessageSerializer,
          scope: OpenStruct.new(
            current_user: current_user,
            user: @user
          )
        ),
        pagination: pagination(messages)
      )

      # render json: @conversation,
      #   serializer: ConversationSerializer,
      #   scope: OpenStruct.new(
      #     current_user: current_user,
      #     user: @user
      #   ),
      #   include_messages: true
    end


    swagger_api :create do |api|
      summary 'create a message'
      param :form, 'body', :string, :required
      param :form, 'receiver_id', :string, :required
      param :form, 'attachable_type', :string, :optional, 'ShopProduct, Album'
      param :form, 'attachable_id', :string, :optional
      # param :form, 'payment_customer_id', :string, :optional
      param :form, 'payment_token', :string, :optional
    end
    def create
      render_error "Please send a message", :unprocessable_entity and return if params[:body].blank?

      sender = current_user
      receiver = User.find(params[:receiver_id])
      message_body = params[:body]
      attachment = nil
      is_balance_available = true
      amount = receiver.repost_price
      stripe_charge_id = nil

      if params[:attachable_id].present?
        payment_token = params[:payment_token]

        unless payment_token.blank?
          stripe_charge_id = Payment.deposit(user: sender, payment_token: payment_token, amount: amount)
          is_balance_available = 'Failed in stripe charge' if stripe_charge_id.blank?
        else
          is_balance_available = 'Not enough balance' if sender.balance_amount < amount
        end

        if is_balance_available === true
          attachment = Attachment.new(
            attachment_type: Attachment.attachment_types[:repost],
            attachable_type: params[:attachable_type],
            attachable_id: params[:attachable_id],
            repost_price: amount,
            payment_customer_id: nil,
            payment_token: stripe_charge_id
          )
        end
      end

      receipt = Util::Message.send(sender, receiver, message_body, nil, attachment)
      conversation = receipt.conversation

      if params[:attachable_id].present? && is_balance_available === true
        attachment = Attachment.attachments_for(receipt.message).first
        payment = Payment.send_repost_request(
          sender: sender,
          receiver: receiver,
          sent_amount: amount,
          payment_token: stripe_charge_id,
          assoc_type: params[:attachable_type],
          assoc_id: params[:attachable_id],
          attachment_id: attachment.id
        ) if attachment.present?
      end

      # authorize receipt.message
      # raise Pundit::NotAuthorizedError unless Mailboxer::MessagePolicy.new(current_user, receipt.message).create?
      # raise Pundit::NotAuthorizedError unless MessagePolicy.new(current_user, receipt.message).create?

      # render json: conversation, serializer: ConversationSerializer, scope: OpenStruct.new(current_user: current_user)
      # render json: MessageSerializer.new(receipt.message, scope: OpenStruct.new(current_user: current_user)).as_json
      render_success true
    end


    swagger_api :delete do |api|
      summary 'delete a message'
    end
    def destroy
    end


    setup_authorization_header(:remove_request_repost)
    swagger_api :remove_request_repost do |api|
      summary 'remove a pending repost'
      param :path, :id, :string, :required
    end
    def remove_request_repost
      message = Mailboxer::Notification.find_by_id(params[:id]) rescue nil
      render_error 'Invalid message id', :unprocessable_entity and return if message.blank?

      attachments = Attachment.attachments_for(message)
      render_error 'Message has not any attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      render_error 'Action has already been taken', :unprocessable_entity and return unless attachment.repost? && attachment.pending?

      attachment.remove

      render_success true
    end


    setup_authorization_header(:accept_repost)
    swagger_api :accept_repost do |api|
      summary 'accept a repost'
      param :path, :id, :string, :required
    end
    def accept_repost
      render_error 'Invalid message id', :unprocessable_entity and return unless params[:id].to_i > 0
      message = Mailboxer::Notification.find_by_id(params[:id])
      attachments = Attachment.attachments_for(message)
      render_error 'message has not an attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      attachable = attachment.attachable

      if attachable.blank?
        attachment.deny(sender: message.sender, receiver: current_user)
        render_error 'attachable not found', :unprocessable_entity and return
      end

      attachment.accept(sender: message.sender, receiver: current_user)
      # attachable.delay.repost(current_user)
      attachable.repost(current_user)

      render_success true
    end


    setup_authorization_header(:deny_repost)
    swagger_api :deny_repost do |api|
      summary 'deny a repost'
      param :path, :id, :string, :required
    end
    def deny_repost
      render_error 'Invalid message id', :unprocessable_entity and return unless params[:id].to_i > 0
      message = Mailboxer::Notification.find_by_id(params[:id])
      attachments = Attachment.attachments_for(message)
      render_error 'Message has not any attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      attachment.deny(sender: message.sender, receiver: current_user)

      render_success true
    end


    setup_authorization_header(:accept_repost_on_free)
    swagger_api :accept_repost_on_free do |api|
      summary 'accept a repost on free'
      param :path, :id, :string, :required
    end
    def accept_repost_on_free
      render_error 'Invalid message id', :unprocessable_entity and return unless params[:id].to_i > 0
      message = Mailboxer::Notification.find_by_id(params[:id])
      attachments = Attachment.attachments_for(message)
      render_error 'message has not an attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      attachable = attachment.attachable

      if attachable.blank?
        attachment.deny(sender: message.sender, receiver: current_user)
        render_error 'attachable not found', :unprocessable_entity and return
      end

      attachment.accept_on_free(sender: message.sender, receiver: current_user)
      attachable.repost(current_user)

      render_success true
    end


    swagger_api :accept_collaboration do |api|
      summary 'accept a collaboration'
      param :path, :id, :string, :required
    end
    def accept_collaboration
      message = Mailboxer::Notification.find_by_id(params[:id])
      attachments = Attachment.attachments_for(message)
      render_error 'message has not an attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      attachable = attachment.attachable

      if attachable.blank?
        attachment.update_attributes(status: Attachment.statuses[:denied])
        render_error 'attachable not found', :unprocessable_entity and return
      end

      attachment.update_attributes(status: Attachment.statuses[:accept])
      case attachment.attachable_type
        when 'Album'
          user_album = UserAlbum.find_by(
            user_id: current_user.id,
            album_id: attachable.id,
            user_type: UserAlbum.user_types[:collaborator],
            status: UserAlbum.statuses[:pending]
          )
          user_album.update_attributes(status: UserAlbum.statuses[:accepted]) if user_album.prensent?
        when 'ShopProduct'
          true
        #   user_product = UserProduct.find_by(
        #     user_id: current_user.id,
        #     product_id: attachable.id,
        #     user_type: UserProduct.user_types[:collaborator],
        #     status: UserProduct.statuses[:pending]
        #   )
        #   user_product.update_attributes(status: UserProduct.statuses[:accepted]) if user_product.prensent?
      end

      render_success true
    end


    setup_authorization_header(:deny_collaboration)
    swagger_api :deny_collaboration do |api|
      summary 'deny a collaboration'
      param :path, :id, :string, :required
    end
    def deny_collaboration
      message = Mailboxer::Notification.find_by_id(params[:message_id])
      attachments = Attachment.attachments_for(message)
      render_error 'Message has not any attachment', :unprocessable_entity and return if attachments.blank? || attachments.length == 0

      attachment = attachments.first
      attachable = attachment.attachable

      if attachable.blank?
        attachment.update_attributes(status: Attachment.statuses[:denied])
        render_error 'attachable not found', :unprocessable_entity and return
      end

      attachment.update_attributes(status: Attachment.statuses[:denied])
      case attachment.attachable_type
        when 'Album'
          user_album = UserAlbum.find_by(
            user_id: current_user.id,
            album_id: attachable.id,
            user_type: UserAlbum.user_types[:collaborator],
            status: UserAlbum.statuses[:pending]
          )
          user_album.update_attributes(status: UserAlbum.statuses[:denied]) if user_album.prensent?
        when 'ShopProduct'
          true
        #   user_product = UserProduct.find_by(
        #     user_id: current_user.id,
        #     product_id: attachable.id,
        #     user_type: UserProduct.user_types[:collaborator],
        #     status: UserProduct.statuses[:pending]
        #   )
        #   user_product.update_attributes(status: UserProduct.statuses[:denied]) if user_product.prensent?
      end

      render_success true
    end


    setup_authorization_header(:has_pending_repost)
    swagger_api :has_pending_repost do |api|
      summary 'has_pending_repost'
      param :form, 'sender_id', :string, :required
      param :form, 'receiver_id', :string, :required
    end
    def has_pending_repost
      sender = User.find_by_username(params[:sender_id]) || User.find(params[:sender_id])
      receiver = User.find_by_username(params[:receiver_id]) || User.find(params[:receiver_id])
      attachments = Attachment.where('mailboxer_notification_id IN (?)', Mailboxer::Notification.joins(:receipts).where('mailbox_type = ? AND receiver_id = ? AND sender_id = ?', 'inbox', receiver.id, sender.id).pluck(:id)).where('status = ?', Attachment.statuses[:pending])

      if attachments.any?
        render_success(true)
      else
        render_success(false)
      end
    end


    setup_authorization_header(:conversations)
    swagger_api :conversations do |api|
      summary 'get conversations'
      param :query, :user_id, :string, :optional
      param :query, :page, :integer, :optional
      param :query, :per_page, :integer, :optional
    end
    def conversations
      enabled_view_dm = current_user.admin? || (current_user.moderator? && current_user.enabled_view_direct_messages)
      render_error 'You are not authorized', :unprocessable_entity and return unless enabled_view_dm || current_user.id == @user.id

      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 50).to_i
      conversations = @user.mailbox.conversations.page(page).per(per_page)

      render_success(
        conversations: ActiveModelSerializers::SerializableResource.new(
          conversations,
          each_serializer: ConversationSerializer,
          scope: OpenStruct.new(
            current_user: current_user,
            user: @user
          )
        ),
        pagination: pagination(conversations)
      ) and return if enabled_view_dm

      blocked_users = @user.blocked_user_objects
      blocked_conversation_ids = []
      blocked_users.each do |blocked_user|
        blocked_conversation_ids += @user.mailbox.conversations_with(blocked_user).collect(&:id)
      end

      # blocked_conversation_ids = []
      # blocked_users.each do |blocked_user|
      #   blocked_conversation_ids += Mailboxer::Conversation.participant(@user).where(
      #     'mailboxer_conversations.id IN (?)', Mailboxer::Conversation.participant(blocked_user).collect(&:id)
      #   ).collect(&:id)
      # end

      inbox_conversation_ids = @user.mailbox.inbox.collect(&:id)
      sentbox_conversation_ids = @user.mailbox.sentbox.collect(&:id)
      conversations = @user.mailbox.conversations
        .where(id: inbox_conversation_ids + sentbox_conversation_ids)
        .where.not(id: blocked_conversation_ids)
        .page(page).per(per_page)

      render_success(
        conversations: ActiveModelSerializers::SerializableResource.new(
          conversations,
          each_serializer: ConversationSerializer,
          scope: OpenStruct.new(
            current_user: current_user,
            user: @user
          )
        ),
        pagination: pagination(conversations)
      )
    end


    swagger_api :delete_conversation do |api|
      summary 'delete all message in a conversation'
      param :query, :conversation_id, :string, :required
    end
    def delete_conversation
      @conversation = Mailboxer::Conversation.find(params[:conversation_id])
      # receipts = Mailboxer::Receipt.conversation(@conversation).where('((receiver_id=? and mailbox_type=?) or (sender_id=? and mailbox_type=?))', current_user.id, 'inbox', current_user.id, 'sentbox') # find all receipts for specific conversation, if user received message it'll be in his/her inbox and he/she will be receiver, if user sent message it'll be in his/her sentbox and he/she will be sender.
      # receipts.destroy_all # delete all messages (conversation maybe more than one message)
      # if @conversation.participants.count == 0 # if all participants deleted this conversation
      #   message_ids = @conversation.messages.pluck(:id)
      #   @conversation.messages.destroy_all     # destroy all conversation's messages
      #   @conversation.destroy                  # destroy the conversation
      #   # puts "\n\n"
      #   # p message_ids
      #   # puts "\n\n\n"
      #   # Attachment.where(mailboxer_notification_id: message_ids).destroy_all
      # end

      @conversation.mark_as_deleted current_user
      render_success(true)
    end

    private

    def set_user
      if params[:user_id].present?
        @user = User.find_by_slug(params[:user_id]) ||
          User.find_by_username(params[:user_id]) ||
          User.find_by_id(params[:user_id]) ||
          current_user
      else
        @user = current_user
      end
    end
  end
end
