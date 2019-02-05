class ShoppingMailer < ApplicationMailer
  default from: ENV['AWS_SES_SUPPORT_EMAIL']
  layout 'mailer'
end