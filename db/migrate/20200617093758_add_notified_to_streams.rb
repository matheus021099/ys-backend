class AddNotifiedToStreams < ActiveRecord::Migration[5.0]
  def change
    add_columns :streams, :notified, :boolean, default: false
  end
end
