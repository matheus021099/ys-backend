class CreateStreams < ActiveRecord::Migration[5.0]
  def change
    create_table :streams do |t|
      t.references :user, index: true
      t.references :genre, index: true
      t.string :name
      t.text :description, default: ''
      t.string :cover

      t.string :ml_input_id
      t.string :ml_input_dest_1_url
      t.string :ml_input_dest_2_url
      t.string :ml_channel_id
      t.string :mp_channel_1_id
      t.string :mp_channel_1_url
      # t.string :mp_channel_1_username
      # t.string :mp_channel_1_password
      t.string :mp_channel_1_ep_1_id
      t.string :mp_channel_1_ep_1_url
      t.string :mp_channel_2_id
      t.string :mp_channel_2_url
      # t.string :mp_channel_2_username
      # t.string :mp_channel_2_password
      t.string :mp_channel_2_ep_1_id
      t.string :mp_channel_2_ep_1_url
      t.string :cf_domain

      t.datetime :started_at
      t.datetime :stopped_at

      # t.string :assoc_type
      # t.integer :assoc_id
      t.references :assoc, polymorphic: true

      t.integer :played_period, default: 0
      t.integer :valid_period, default: 0
      t.integer :view_price, :integer, default: 0
      t.integer :viewers_limit, :integer, default: 0

      t.string :status, default: 'active'
      t.timestamps
    end

    add_index :streams, [:id, :user_id]
  end
end
