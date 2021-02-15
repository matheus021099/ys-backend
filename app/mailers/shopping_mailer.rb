class ShoppingMailer < ApplicationMailer
  default from: "YouSound <#{ENV['AWS_SES_ORDER_EMAIL']}>"
  layout 'mailer'
end
