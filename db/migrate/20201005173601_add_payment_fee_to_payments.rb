class AddPaymentFeeToPayments < ActiveRecord::Migration[5.0]
  def change
    add_column :payments, :payment_fee, :integer, default: 0
  end
end
