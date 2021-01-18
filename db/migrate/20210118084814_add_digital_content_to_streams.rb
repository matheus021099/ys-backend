class AddDigitalContentToStreams < ActiveRecord::Migration[5.0]
  def change
    add_column :streams, :digital_content, :string
    add_column :streams, :digital_content_name, :string
    # user_ids to viewer can follow
    add_column :streams, :account_ids, :text, array: true, default: []
  end
end
