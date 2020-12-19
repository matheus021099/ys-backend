class CreateUsersStreams < ActiveRecord::Migration[5.0]
  def change
    create_table :users_streams do |t|
      t.references :user
      t.references :stream
      t.string :user_type
      t.integer :user_share, default: 100
      t.integer :recoup_cost, default: 0
      t.integer :recoup_paid, default: 0

      t.string :status
      t.timestamps
    end
  end
end
