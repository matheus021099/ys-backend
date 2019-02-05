class UserMailer < Devise::Mailer   
  helper MailerHelper
  
  default from: ENV['AWS_SES_SUPPORT_EMAIL']
  layout 'mailer'
end