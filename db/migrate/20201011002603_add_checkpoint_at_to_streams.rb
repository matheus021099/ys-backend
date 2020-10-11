class AddCheckpointAtToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :checkpoint_at, :datetime
    add_column :streams, :cost, :float, default: 0.0
    add_column :streams, :watching_viewers, :integer, default: 0
    add_column :streams, :total_viewers, :integer, default: 0
  end
end
