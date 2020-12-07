class ShoppingMailer < ApplicationMailer
  default from: "YouSound <#{ENV['AWS_SES_SUPPORT_EMAIL']}>"
  layout 'mailer'
end
