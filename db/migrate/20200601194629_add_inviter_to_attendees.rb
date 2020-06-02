class AddInviterToAttendees < ActiveRecord::Migration[5.0]
  def change
    add_column :attendees, :inviter_id, :integer
  end
end
