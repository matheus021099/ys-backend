module Api::V1
  class AttendeesController < ApiController
    skip_before_action :authenticate_token!, only: [:create, :find_by_token]
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_attendee, only: [:invite]

    swagger_controller :attendee, 'attendee'

    setup_authorization_header(:index)
    swagger_api :index do |api|
      summary 'get attendees'
    end
    def index
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
      attendees = Attendee.includes(:user).all
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
      render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?

      now = Time.now
      invitation_token = SecureRandom.urlsafe_base64(16)

      @attendee.update_attributes(
        invitation_token: invitation_token,
        invited_at: now,
        status: Attendee.statuses[:invited]
      )

      ApplicationMailer.to_attendee_invitation_email(@attendee).deliver

      render_success true
    end
    # def invite_attendee
    #   render_error 'You are not authorized', :unprocessable_entity and return unless current_user.admin?
    #   attendee = Attendee.find(params[:attendee_id])
    #   names = attendee.full_name.split(' ').map(&:strip)
    #   first_name = names.shift
    #   last_name = names.join(' ')
    #   username = attendee.display_name.downcase.gsub(/\s+/, '_')
    #   # password = [*('a'..'z'),*('0'..'9')].shuffle[0,8].join
    #   begin
    #     password = 'password'
    #     user = User.new(
    #       first_name: first_name,
    #       last_name: last_name,
    #       email: attendee.email,
    #       display_name: attendee.display_name,
    #       username: username,
    #       password: password,
    #     )
    #     user.skip_confirmation_notification!
    #     user.save!
    #     attendee.update_attributes(status: Attendee.statuses[:invited])
    #   rescue => ex
    #     Rails.logger.info ex.message
    #     attendee.update_attributes(status: Attendee.statuses[:existed])
    #     render_error ex.message, :unprocessable_entity and return
    #   end
    #   user.apply_role(attendee.account_type)
    #   ### send a message that account is pending to approve
    #   message_body = ''
    #   case attendee.account_type
    #     when 'brand'
    #       message_body = "Welcome to YouSound!<br><br>Brands are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You can earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with your friends, and build relationships with the YouSound community.<br><br>As a Brand you can sell your products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
    #     when 'label'
    #       message_body = "Welcome to YouSound!<br><br>Labels are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You can earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with friends & build relationships within the YouSound community.<br><br>As a Label you can request artists and their albums to be apart of your roster, sell products, collaborate on products with other Artists, Brands, and Labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
    #     else
    #       message_body = "Welcome to YouSound!<br><br>Artists are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can repost products, and repost your favorite live video broadcasts.<br><br>You have the ability to help Artists, Brands, and Labels reach more users. You can also earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room and can hang out with your friends, and build relationships with the YouSound community.<br><br>As an artist you can upload albums, sell products, collaborate on albums with other artists, collaborate on products with other artists, brands, and labels, and run live video broadcasts. You can also invite any pending account waiting to be verified and expedite their verification process.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
    #   end
    #   sender = User.admin
    #   receiver = user
    #   receipt = Util::Message.send(sender, receiver, message_body)
    #   ### admin follow user
    #   sender.follow(receiver)
    #   ### confirm message to activate an account
    #   user.send_confirmation_instructions
    #   render_success true
    # end

    private
    def set_attendee
      @attendee = Attendee.find(params[:id])
    end
  end
end