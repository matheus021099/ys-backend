module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      params = request.query_parameters()
      self.current_user = get_user(params[:token])
    end

    private
    def get_user(token)
      user = User.valid_token? token
      if user.instance_of? User
        user
      else
        reject_unauthorized_connection
      end
    end
  end
end
