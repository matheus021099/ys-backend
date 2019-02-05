module Api::V1::Shopping
  class ApiController < Api::V1::ApiController
    # before_action :current_cart
    # private
    # def current_cart
    #   ShopCart.find_or_create_by(
    #     customer_id: current_user.id
    #   ) if user_signed_in?
    #   # ShopCart.find_or_create_by_customer_id_and_status(
    #   #   customer_id: @customer.id,
    #   #   status: ShopCart.statuses[:cart_not_paid]
    #   # ) if user_signed_in?
    # end
  end
end