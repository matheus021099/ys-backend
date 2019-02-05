class CreateAttendees < ActiveRecord::Migration[5.0]
  def change
    create_table :attendees do |t|
      t.string :full_name
      t.string :display_name
      t.string :email
      t.string :account_type, default: 'artist'
      t.string :referred_by, default: ''
      t.references :referrer, references: :user
      t.references :user

      t.string :invitation_token
      t.datetime :invited_at

      t.string :status, default: 'created'
      t.timestamps
    end

    add_index :attendees, :email, unique: true
    add_index :attendees, :display_name, unique: true
    add_index :attendees, :invitation_token, unique: true
  end
end
