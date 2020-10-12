class AddRemainingSecondsToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :remaining_seconds, :integer, default: 0
  end
end
