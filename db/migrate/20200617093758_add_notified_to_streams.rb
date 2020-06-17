class AddNotifiedToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :notified, :boolean, default: false
  end
end
