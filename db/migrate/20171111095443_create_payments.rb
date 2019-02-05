class CreatePayments < ActiveRecord::Migration[5.0]
  def change
    create_table :payments do |t|
      t.references :sender, references: :user
      t.string :sender_stripe_id
      t.references :receiver, references: :user
      t.string :receiver_stripe_id

      t.string :description, default: ''
      t.string :payment_type
      t.string :payment_token
      t.integer :sent_amount, default: 0
      t.integer :received_amount
      t.integer :fee, default: 0
      t.integer :shipping_cost, default: 0
      t.integer :tax, default: 0
      t.integer :refund_amount, default: 0

      t.references :assoc, polymorphic: true

      t.references :order, references: :shop_orders, index: true
      t.integer :user_share, default: 0

      t.references :attachment, index: true

      t.string :status
      t.timestamps
    end
  end
end
