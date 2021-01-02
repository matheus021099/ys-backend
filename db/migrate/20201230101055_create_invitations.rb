class CreateInvitations < ActiveRecord::Migration[5.0]
  def change
    create_table :invitations do |t|
      t.references :user
      t.references :inviter, references: :user
      t.string :invitation_token

      t.string :status
      t.timestamps
    end
  end
end
