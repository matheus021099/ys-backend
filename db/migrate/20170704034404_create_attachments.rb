class CreateAttachments < ActiveRecord::Migration[5.0]
  def change
    create_table :attachments do |t|
      t.integer :mailboxer_notification_id
      t.string :attachment_type, default: 'repost'
      t.references :attachable, :polymorphic => true
      t.string :payment_customer_id
      t.string :payment_token
      t.integer :repost_price, default: 100, null: false

      t.string :status
      t.timestamps
    end
  end
end
