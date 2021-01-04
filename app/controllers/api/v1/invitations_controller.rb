module Api::V1
  class InvitationsController < ApiController
    helper MailerHelper

    swagger_controller :invitations, 'invitation'


    swagger_api :create do |api|
      summary 'create an invitation'
    end
    def create
      skip_authorization

      @invitation = Invitation.new
      @invitation.inviter = current_user
      @invitation.invitation_token = SecureRandom.urlsafe_base64(16)

      render_error 'failed', :unprocessable_entity unless @invitation.save

      render_success {
        url: invitation_url(nil, @invitation.invitation_token)
      }
    end


    swagger_api :find_by_token do |api|
      summary 'Find an invitation by token'
      param :query, :token, :string, :required, 'invitation_token'
    end
    def find_by_token
      render_error 'Token missed', :unprocessable_entity and return if params[:token].blank?

      @invitation = Invitation.find_by(invitation_token: params[:token], status: Invitation.statuses[:pending])

      render_error 'Token invalid', :unprocessable_entity and return unless @invitation.present?

      if @invitation.invited_at < 3.days.ago
        @invitation.update_attributes(status: Invitation.statuses[:expired])
        render_error 'Token expired', :unprocessable_entity and return
      end

      render_success UserSerializer1.new(@invitation.inviter).as_json
    end
  end
end
