module Api::V1
  class InvitationsController < ApiController
    swagger_controller :invitations, 'invitation'


    swagger_api :create do |api|
      summary 'create an invitation'
    end
    def create
      skip_authorization

      @invitation = Invitation.new
      @invitation.inviter = current_user
      @invitation.invitation_token = SecureRandom.urlsafe_base64(16)

      render_success @invitation.save
    end
  end
end
