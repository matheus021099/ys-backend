require 'openssl'
require 'csv'

module Api::V1
  class AuthsController < ApiController
    skip_before_action :authenticate_token!, except: [:sign_out]

    swagger_controller :auth, "Authentication"

    swagger_api :sign_in do |api|
      summary "Sign in with email and password"
      param :form, "email", :string, :required, "Email"
      param :form, "password", :string, :required, "Password"
    end
    def sign_in
      skip_authorization
      user = User.find_for_authentication(email: params[:email])
      if user.present? && user.valid_password?(params[:password])
        if user.active_for_authentication?
          user.update_tracked_fields! request
          Activity.create(
            sender_id: user.id,
            receiver_id: user.id,
            message: 'signed in',
            module_type: Activity.module_types[:activity],
            action_type: Activity.action_types[:signin],
            alert_type: Activity.alert_types[:both],
            status: Activity.statuses[:read]
          )
          user_json = UserSerializer.new(
            user,
            scope: OpenStruct.new(current_user: user),
            include_social_info: true,
            include_all: true).as_json
          user_json[:token] = JsonWebToken.encode(user_json)
          user_json[:hmac] = OpenSSL::HMAC.hexdigest('sha256', ENV['INTERCOM_SECRET_KEY'], user.id.to_s)
          render_success(user_json)
        else
          render_error('Inactive user', :unauthorized)
        end
      else
        render_error('Invalid email or password', :unauthorized)
      end
    end


    setup_authorization_header(:sign_out)
    swagger_api :sign_out do |api|
      summary "Sign out"
    end
    def sign_out
      skip_authorization
      # current_user.update_attributes(
      #   current_sign_in_at: nil,
      #   current_sign_in_ip: nil
      # )
      current_user.stream.remove if current_user.stream.present?
      Activity.create(
        sender_id: current_user.id,
        receiver_id: current_user.id,
        message: 'signed out',
        module_type: Activity.module_types[:activity],
        action_type: Activity.action_types[:signout],
        alert_type: Activity.alert_types[:both],
        status: Activity.statuses[:read]
      )
      render_success true
    end


    swagger_api :sign_up_as_listener do |api|
      summary "sign up as listener"
      param :form, "user[invitation_token]", :string, :optional

      param :form, "user[username]", :string, :required
      param :form, "user[display_name]", :string, :required
      param :form, "user[email]", :string, :required
      param :form, "user[password]", :string, :required
      param :form, "user[avatar]", :File, :required

      param :form, "user[request_role]", :string, :optional, 'artist, brand, label'
      param :form, "user[social_user_id]", :string, :optional
      param :form, "user[genre_id]", :string, :optional
      param :form, "user[year_of_birth]", :string, :optional
      param :form, "user[gender]", :string, :optional
      param :form, "user[country]", :string, :optional
      param :form, "user[city]", :string, :optional
      param :form, "user[artist_type]", :string, :optional
      param :form, "user[released_albums_count]", :string, :optional
      param :form, "user[years_since_first_released]", :string, :optional
      param :form, "user[will_run_live_video]", :string, :optional
      param :form, "user[will_sell_products]", :string, :optional
      param :form, "user[will_sell_physical_copies]", :string, :optional
      param :form, "user[annual_income_on_merch_sales]", :string, :optional
      param :form, "user[annual_performances_count]", :string, :optional
      param :form, "user[signed_status]", :string, :optional
      param :form, "user[performance_rights_organization]", :string, :optional
      param :form, "user[ipi_cae_number]", :string, :optional
      param :form, "user[website_1_url]", :string, :optional
      param :form, "user[website_2_url]", :string, :optional
      param :form, "user[sub_genre_id]", :string, :optional
      param :form, "user[is_business_registered]", :string, :optional
      param :form, "user[artists_count]", :string, :optional
      param :form, "user[standard_brand_type]", :string, :optional
      param :form, "user[customized_brand_type]", :string, :optional
      param :form, "user[employees_count]", :string, :optional
      param :form, "user[years_in_business]", :string, :optional
      param :form, "user[will_sell_music_related_products]", :string, :optional
      param :form, "user[products_count]", :string, :optional
      param :form, "user[annual_income]", :string, :optional
      param :form, "user[history]", :string, :optional
    end
    def sign_up_as_listener
      skip_authorization
      render_error 'Please upload the avatar', :unprocessable_entity and return unless params[:user][:avatar].instance_of? ActionDispatch::Http::UploadedFile

      validate_need = false
      user = User.find_by_email(params[:user][:email])
      if user.present? && user.deleted?
        Rails.logger.info("#{user.email} - #{user.username}")
        user.attributes = permitted_attributes(user)
        user.status = User.statuses[:inactive]
      else
        Rails.logger.info('user create')
        user = User.new(status: User.statuses[:inactive])
        user.attributes = permitted_attributes(user)
        validate_need = true
      end

      unless user.request_role.blank?
        user.request_status = User.request_statuses[:pending]
      end
      # user.skip_confirmation!
      user.skip_confirmation_notification!

      if user.save(validate: validate_need)
        Activity.create(
          sender_id: user.id,
          receiver_id: user.id,
          message: 'signed up',
          module_type: Activity.module_types[:activity],
          action_type: validate_need ? Activity.action_types[:signup] : Activity.action_types[:singup_resume],
          alert_type: Activity.alert_types[:both],
          status: Activity.statuses[:read]
        )
        ### make a relation between a user and an attendee
        unless params[:user][:invitation_token].blank?
          attendee = Attendee.find_by(invitation_token: params[:user][:invitation_token])
          if attendee.present?
            attendee.update_attributes(
              invitation_token: nil,
              invited_at: nil,
              user_id: user.id,
              status: Attendee.statuses[:accepted]
            )
          end
        end
        ### send a welcome message
        if validate_need
          sender = User.admin
          receiver = user
          message_body = "Welcome to YouSound!<br><br>Listeners are valuable members of the YouSound community. All music is free to stream and download, and when you download an album it’s automatically reposted to your followers. You can also repost products, and repost your favorite live video broadcasts.<br><br>You can earn revenue by reposting content from Verified Users via Repost Requests. Each user has their own chat room to hang out with friends & build relationships within the YouSound community.<br><br>Learn more by visiting the <a href='https://support.yousound.com' target='_blank'>Support page</a>"
          receipt = Util::Message.send(sender, receiver, message_body)
          conversation = receipt.conversation

          ### send a message that account is pending to approve
          unless user.request_role.blank?
            message_body = "Your request to become a Verified User is pending. We will send you an email when the verification process is complete. In the meantime you can browse as a listener."
            sender.reply_to_conversation(conversation, message_body, nil, true, false)
          end

          ### admin follow user
          sender.follow(receiver)
        end
        user.send_confirmation_instructions
        render_success(user)
      else
        # render_errors(user, :unprocessable_entity)
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end


    swagger_api :sign_up_as_artist do |api|
      summary "sign up as artist"
      param :form, "user[username]", :string, :required
      param :form, "user[display_name]", :string, :required
      param :form, "user[email]", :string, :required
      param :form, "user[password]", :string, :required
      param :form, "user[avatar]", :File, :required
      param :form, "user[social_user_id]", :string, :required
      param :form, "user[role]", :string, :required, 'artist, brand, label'
    end
    def sign_up_as_artist
      skip_authorization

      user = User.where(social_user_id: params[:user][:social_user_id]).first
      # render_error('you should register your facebook account first', 200) and return if user.blank?
      # render_error('your facebook account is being verified', 200) and return if user.pending?
      # render_error('something is wrong', 200) and return unless user.verified?

      render_error 'Social account already exists', :unprocessable_entity and return if user.present?

      user = User.new(status: User.statuses[:inactive])
      user.attributes = permitted_attributes(user)
      if user.save
        user.apply_role(params[:user][:role])
        user.reload
        render_success(user)
      else
        render_errors(user, :unprocessable_entity)
      end
    end


    swagger_api :send_confirm_email do |api|
      summary "confirm with token"
      param :form, :email, :string, :required
    end
    def send_confirm_email
      skip_authorization
      render_error 'Not passed email', :unprocessable_entity and return unless params[:email].present?

      user = User.find_by(email: params[:email])
      render_error 'Not found', :unprocessable_entity and return unless user.present?

      # render_error 'Already confirmed', :unprocessable_entity and return unless user.confirmed_at.nil?

      user.send_confirmation_instructions
      render_success true
    end


    swagger_api :confirm do |api|
      summary "confirm with token"
      param :form, :confirmation_token, :string, :required
    end
    def confirm
      skip_authorization

      user = User.confirm_by_token(params[:confirmation_token])
      if user.errors.empty?
        # if user.listener?
        #   user.update_attributes(status: User.statuses[:active])
        # else
        #   user.update_attributes(status: User.statuses[:verified])
        # end
        user.update_attributes(status: User.statuses[:active])
        render_success(user)
      else
        render_errors(user, :unprocessable_entity)
      end
    end


    swagger_api :signin_url_for_twitter do |api|
      summary 'signin url for twitter'
      param :form, :callback, :string, :required
    end
    def signin_url_for_twitter
      skip_authorization
      oauth_callback = params[:callback] || ''

      oauth = OAuth::Consumer.new(
        ENV['TWITTER_API_KEY'],
        ENV['TWITTER_API_SECRET'], {
          site: 'https://api.twitter.com',
          authorize_path: '/oauth/authenticate'
        })
      response = oauth.get_request_token oauth_callback: oauth_callback
      render_success(url: response.authorize_url)
    end


    swagger_api :signin_with_social do |api|
      summary 'signin with social'
      param :form, :provider, :string, :required, 'facebook, twitter, google, etc'
      param :form, :email, :string, :required
      param :form, :user_id, :string, :required
      param :form, :user_name, :string, :optional
      param :form, :token, :string, :optional
      param :form, :token_secret, :string, :optional
    end
    def signin_with_social
      skip_authorization

      user = User.from_omniauth(params)
      if user.persisted?
        user_json = UserSerializer.new(
          user,
          scope: OpenStruct.new(current_user: user),
          include_social_info: true
        ).as_json
        user_json[:token] = JsonWebToken.encode(user_json) if user.active_for_authentication?
        render_success(user_json)
      else
        render_error(user, :unprocessable_entity)
      end
    end


    # swagger_api :login_with_google do |api|
    #   summary 'Login with Google'
    #   param :form, :auth_token, :string, :required
    # end
    # def login_with_google
    #   skip_authorization
    #   info = JWT.decode params[:auth_token], nil, false
    #   user = User.from_omniauth(:google, {
    #     email: info[0]['email'], 
    #     uid: info[0]['sub'],
    #     first_name: info[0]['given_name'], 
    #     last_name: info[0]['family_name']
    #   })
    #   if user.persisted?
    #     user_json = UserSerializer.new(user).as_json
    #     user_json[:token] = JsonWebToken.encode(user_json)
    #     render_success(user_json)
    #   else
    #     render_error(user, :unprocessable_entity)
    #   end
    # rescue JWT::ExpiredSignature
    #   render_error('Auth token has expired', :unauthorized)
    # rescue JWT::DecodeError
    #   render_error('Invalid auth token', :unauthorized)
    # end

    #TODO: update_password


    swagger_api :reset_password do |api|
      summary 'Reset user pasword'
      param :form, :email, :string, :required
    end
    def reset_password
      user = User.find_by(email: params[:email])
      if user.present?
        authorize user
        user.send_reset_password_instructions
        render_success(true)
      else
        skip_authorization
        render_error("Email doesn't exist", :unprocessable_entity)
      end
    end


    swagger_api :set_password do |api|
      summary 'Set user pasword with reset token'
      param :form, :reset_token, :string, :required
      param :form, :password, :string, :required
    end
    def set_password
      user = User.reset_password_by_token({ 
        reset_password_token: params[:reset_token], 
        password: params[:password],
        password_confirmation: params[:password],
      })
      if user.errors.empty?
        authorize user, :reset_password?
        render_success(true)
      else
        skip_authorization
        render_errors(user, :unprocessable_entity)
      end
    end


    swagger_api :is_username_available do |api|
      summary "check username is available"
      param :form, "username", :string, :required, "Username"
    end
    def is_username_available
      skip_authorization
      render_json and return unless params[:username].present?

      user = User.find_by(username: params[:username].downcase)
      render_error 'Already exists', :unprocessable_entity and return if user.present?

      render_success true
    end


    swagger_api :token_validity do |api|
      summary 'Check if token is valid'
      param :form, :auth_token, :string, :required
    end
    def token_validity
      skip_authorization
      user = User.valid_token? params[:auth_token]
      render_success false and return unless user.instance_of? User
      user_json = UserSerializer.new(
        user,
        scope: OpenStruct.new(current_user: user),
        include_all: true,
        include_social_info: true
      ).as_json
      user_json[:hmac] = OpenSSL::HMAC.hexdigest('sha256', ENV['INTERCOM_SECRET_KEY'], user.id.to_s)
      render_success(user_json)
    end
    # def token_validity
    #   skip_authorization
    #   payload = JsonWebToken.decode(params[:auth_token])
    #   user = User.find(payload['id'])
    #   render_success(user)
    #   rescue JWT::ExpiredSignature
    #     render_error('Auth token has expired', :unauthorized)
    #   rescue Exception
    #     render_error('Invalid auth token', :unauthorized)
    # end
  end
end
