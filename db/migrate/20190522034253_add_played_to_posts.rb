class AddPlayedToPosts < ActiveRecord::Migration[5.0]
  def change
    add_column :posts, :played, :integer, default: 0
    add_column :posts, :downloaded, :integer, default: 0
  end
end
