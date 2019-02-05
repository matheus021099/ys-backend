class DeviseCreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ''
      t.string :encrypted_password, null: false, default: ''

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Trackable
      t.integer  :sign_in_count, default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.inet     :current_sign_in_ip
      t.inet     :last_sign_in_ip

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      ## Lockable
      t.integer  :failed_attempts, default: 0, null: false # Only if lock strategy is :failed_attempts
      t.string   :unlock_token # Only if unlock strategy is :email or :both
      t.datetime :locked_at

      ## Profile
      t.string  :username
      t.string  :display_name
      t.string  :user_type, default: 'listener'
      t.string  :first_name
      t.string  :last_name
      t.string  :slug
      t.string  :avatar
      t.string  :contact_url
      t.boolean :enable_alert, default: false
      t.integer :repost_price, default: 100, null: false # in cent
      t.integer :address_id
      t.integer :timezone_offset
      t.integer :followings_count, default: 0
      t.integer :followers_count, default: 0

      ## Invitations
      t.integer :invited_user_id
      t.integer :invitation_limit # < 0: unlimited, = 0: disabled, > 0
      t.boolean :consigned, default: false
      t.integer :inviter_id
      t.datetime :invited_at

      ## Social Login
      t.string  :social_provider
      t.string  :social_user_id
      t.string  :social_user_name
      t.string  :social_token
      t.string  :social_token_secret

      ## Payment
      t.string  :payment_provider
      t.string  :payment_account_id
      t.string  :payment_account_type
      t.string  :payment_publishable_key
      t.string  :payment_access_code

      t.integer   :balance_amount, default: 0
      t.datetime  :repost_price_end_at
      t.datetime  :message_first_visited_time

      t.integer   :approver_id, index: true
      t.datetime  :approved_at

      t.text  :return_policy, default: ''
      t.text  :shipping_policy, default: ''
      t.text  :privacy_policy, default: ''
      t.text  :size_chart, default: ''

      t.boolean :enabled_live_video, default: true
      t.boolean :enabled_live_video_free, default: false
      t.boolean :enabled_view_direct_messages, default: false
      t.integer :stream_rolled_time, default: 0
      t.integer :stream_rolled_cost, default: 0
      t.integer :free_streamed_time, default: 0
      t.integer :max_repost_price, default: 100

      t.string :request_role
      t.string :request_status
      t.string :denial_reason, default: ''
      t.text  :denial_description, default: ''

      t.integer :genre_id
      t.integer :sub_genre_id
      t.integer :year_of_birth, default: 0
      t.string :gender, default: ''
      t.string :country, default: ''
      t.string :city, default: ''

      t.string :artist_type, default: ''
      t.integer :released_albums_count, default: 0
      t.integer :years_since_first_released, default: 0
      t.boolean :will_run_live_video, default: true
      t.boolean :will_sell_products, default: true
      t.boolean :will_sell_physical_copies, default: true
      t.integer :annual_income_on_merch_sales, default: 0
      t.integer :annual_performances_count, default: 0
      t.string :signed_status, default: ''
      t.string :performance_rights_organization, default: ''
      t.string :ipi_cae_number, default: ''
      t.text :website_1_url, default: ''
      t.text :website_2_url, default: ''
      t.text :history, default: ''

      t.boolean :is_business_registered, default: true
      t.integer :artists_count, default: 0

      t.string :standard_brand_type, default: ''
      t.string :customized_brand_type, default: ''
      t.integer :employees_count, default: 1
      t.integer :years_in_business, default: 0
      t.boolean :will_sell_music_related_products, default: true
      t.integer :products_count, default: 0
      t.integer :annual_income, default: 0

      t.string  :status
      t.timestamps null: false
    end

    add_index :users, :username,             unique: true
    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :confirmation_token,   unique: true
    add_index :users, :unlock_token,         unique: true
    add_index :users, :slug, unique: true
  end
end
