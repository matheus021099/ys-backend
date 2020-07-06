class UserMailer < Devise::Mailer
  helper MailerHelper

  default from: ENV['AWS_SES_NOREPLY_EMAIL']
  layout 'mailer'
end
