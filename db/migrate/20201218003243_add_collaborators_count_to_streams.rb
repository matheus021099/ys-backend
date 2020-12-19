class AddCollaboratorsCountToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :collaborators_count, :integer, default: 0
  end
end
