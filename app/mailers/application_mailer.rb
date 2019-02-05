class ApplicationMailer < ActionMailer::Base
  helper MailerHelper

  default from: ENV['AWS_SES_SUPPORT_EMAIL']
  layout 'mailer'

  def to_buyer_order_email(order)
    @order = order
    mail(
      template_path: 'shopping_mailer',
      to: @order.customer.email,
      subject: 'you placed new order'
    )
  end

  def to_seller_order_email(order)
    @order = order
    mail(
      template_path: 'shopping_mailer',
      to: @order.merchant.email,
      subject: 'new order has arrived'
    )
  end

  def to_requester_approved_email(verifier, requester)
    @verifier = verifier
    @requester = requester
    mail(
      template_path: 'user_mailer',
      to: @requester.email,
      subject: 'request role has been approved'
    )
  end

  def to_requester_denied_email(verifier, requester)
    @verifier = verifier
    @requester = requester
    mail(
      template_path: 'user_mailer',
      to: @requester.email,
      subject: 'request role has been denied'
    )
  end

  # def confirmation_email(user)
  #   @email = user.email
  #   @token = user.confirmation_token
  #   mail(
  #     template_path: 'user_mailer',
  #     template_name: 'confirmation_instructions',
  #     to: user.email,
  #     subject: 'Confirm your account'
  #   )
  # end

  def to_attendee_invitation_email(attendee)
    @attendee = attendee
    mail(
      template_path: 'user_mailer',
      to: @attendee.email,
      subject: 'invited to yousound.com'
    )
  end
end
