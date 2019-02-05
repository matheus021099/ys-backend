class JsonWebToken
  def self.encode(payload, remember_me = false)
    expiration = 24.hours.from_now.to_i
    expiration = 15.days.from_now.to_i if remember_me
    JWT.encode payload.merge(exp: expiration), Rails.application.secrets.secret_key_base
  end

  def self.decode(token)
    JWT.decode(token, Rails.application.secrets.secret_key_base).first
  end
end