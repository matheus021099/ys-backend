module Api::V1
  class AttendeesController < ApiController
    skip_before_action :authenticate_token!, only: [:create, :find_by_token]
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_attendee, only: [:destroy, :invite]

    swagger_controller :attendee, 'attendee'

    setup_authorization_header(:index)
    swagger_api :index do |api|
      summary 'get attendees'
    end
    def index
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?
      attendees = Attendee.includes(:user).order(created_at: :desc).all
      result = ActiveModel::Serializer::CollectionSerializer.new(
        attendees,
        serializer: AttendeeSerializer
      )
      render json: result
    end
    # def index
    #   render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
    #   filename = "log/attendees.csv"
    #   rows = []
    #   if File.exists?(filename)
    #     rows = CSV.read(filename, col_sep: ",", headers: true, header_converters: :symbol)
    #   end
    #   result = []
    #   rows.each do |r|
    #     # puts '+++++'
    #     # p r
    #     # p r.to_hash
    #     # puts '-----'
    #     result << r.to_hash
    #   end
    #   render json: result
    # end


    swagger_api :create do |api|
      summary 'Add an attendee'
      param :form, "attendee[full_name]", :string, :required
      param :form, "attendee[display_name]", :string, :required
      param :form, "attendee[email]", :string, :required
      param :form, "attendee[account_type]", :string, :required
      param :form, "attendee[referred_by]", :string, :optional
    end
    def create
      skip_authorization
      attendee_attributes = params.require(:attendee).permit(:full_name, :display_name, :email, :account_type, :referred_by)

      attendee = Attendee.new
      attendee.attributes = attendee_attributes
      attendee.save!

      render_success true
      rescue Exception => e
        render_error e.message, :unprocessable_entity and return
    end
    # def create
    #   skip_authorization
    #   attendee = params.require(:attendee).permit(:full_name, :display_name, :email, :account_type, :referred_by)
    #   render_error 'Invalid params', :unprocessable_entity and return if attendee['full_name'].blank? || attendee['display_name'].blank? || attendee['email'].blank? || attendee['account_type'].blank?
    #   # puts '++++'
    #   # p attendee[:full_name]
    #   # p attendee['full_name']
    #   # puts '----'
    #   filename = 'log/attendees.csv'
    #   if !File.exists?(filename)
    #     CSV.open(filename, 'a') do |csv|
    #       csv << ['full_name', 'display_name', 'email', 'account_type', 'referred_by']
    #     end
    #   end
    #   CSV.open(filename, "a") do |csv|
    #     csv << [attendee['full_name'], attendee['display_name'], attendee['email'], attendee['account_type'], attendee['referred_by'] || '']
    #   end
    #   render_success true
    #   rescue Exception => e
    #     render_error e.message, :unprocessable_entity and return
    # end


    setup_authorization_header(:destroy)
    swagger_api :destroy do |api|
      summary 'Destory an attendee'
      param :path, :id, :string, :required, 'attendee id'
    end
    def destroy
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?

      @attendee.destroy

      render_success true
    end


    swagger_api :find_by_token do |api|
      summary 'Find an attendee by token'
      param :query, :token, :string, :required, 'invitation_token'
    end
    def find_by_token
      render_error 'Token missed', :unprocessable_entity and return if params[:token].blank?

      attendee = Attendee.find_by(invitation_token: params[:token])

      render_error 'Token invalid', :unprocessable_entity and return unless attendee.present?

      if attendee.invited_at < 3.days.ago
        attendee.update_attributes(status: Attendee.statuses[:expired])
        render_error 'Token expired', :unprocessable_entity and return
      end

      render_success attendee
    end


    setup_authorization_header(:invite)
    swagger_api :invite do |api|
      summary 'Invite an attendee'
      param :path, :id, :string, :required, 'attendee id'
    end
    def invite
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin? || current_user.moderator?

      user = User.find_by(email: @attendee.email)
      render_error 'Email has already been taken', :unprocessable_entity and return if user.present?

      now = Time.now
      invitation_token = SecureRandom.urlsafe_base64(16)

      @attendee.update_attributes(
        invitation_token: invitation_token,
        inviter_id: current_user.id,
        invited_at: now,
        status: Attendee.statuses[:invited]
      )

      ApplicationMailer.to_attendee_invitation_email(@attendee).deliver

      render_success true
    end

    private
    def set_attendee
      @attendee = Attendee.find(params[:id])
    end
  end
end
