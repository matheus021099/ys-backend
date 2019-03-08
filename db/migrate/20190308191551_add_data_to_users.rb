class AddDataToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :data, :jsonb, default: {}
  end
end
