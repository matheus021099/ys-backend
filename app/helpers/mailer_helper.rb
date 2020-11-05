module MailerHelper
  def reset_password_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/reset_password/#{token}"
    else
      "#{app_path}/reset_password/#{token}"
    end
  end

  def confirmation_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/confirm/#{token}"
    else
      "#{app_path}/confirm/#{token}"
    end
  end

  def login_url(app_path)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/login"
    else
      "#{app_path}/login"
    end
  end

  def invitation_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/register/attendee/#{token}"
    else
      "#{app_path}/register/attendee/#{token}"
    end
  end

  def unlock_url(app_path, token)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/auth/unlock/#{token}"
    else
      "#{app_path}/auth/unlock/#{token}"
    end
  end

  def order_detail_url(app_path, order_id)
    if app_path.blank?
      "#{ENV['WEB_BASE_URL']}/sell/order/#{order_id}"
    else
      "#{app_path}/sell/order/#{order_id}"
    end
  end

  def smart_add_url_protocol(url)
    unless url[/\Ahttps:\/\//] || url[/\Ahttp:\/\//]
      url = "https://#{url}"
    end
    url
  end
end