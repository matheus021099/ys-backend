class UserMailer < Devise::Mailer
  helper MailerHelper

  default from: "YouSound <#{ENV['AWS_SES_NOREPLY_EMAIL']}>"
  layout 'mailer'
end
