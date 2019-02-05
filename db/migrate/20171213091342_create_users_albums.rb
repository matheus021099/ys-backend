class CreateUsersAlbums < ActiveRecord::Migration[5.0]
  def change
    create_table :users_albums do |t|
      t.references :user
      t.references :album
      t.string :user_type
      t.string :user_role

      t.string :status
      t.timestamps
    end
  end
end
