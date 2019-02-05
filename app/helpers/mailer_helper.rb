module MailerHelper
  def reset_password_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_APP_PATH']}/reset_password/#{token}"
    else
      "#{app_path}/reset_password/#{token}"
    end
  end

  def confirmation_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_APP_PATH']}/confirm/#{token}"
    else
      "#{app_path}/confirm/#{token}"
    end
  end

  def login_url(app_path)
    if app_path.blank?
      "#{ENV['WEB_APP_PATH']}/login"
    else
      "#{app_path}/login"
    end
  end

  def invitation_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_APP_PATH']}/register/attendee/#{token}"
    else
      "#{app_path}/register/attendee/#{token}"
    end
  end
end