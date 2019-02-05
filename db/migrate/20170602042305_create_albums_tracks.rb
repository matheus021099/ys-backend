class CreateAlbumsTracks < ActiveRecord::Migration[5.0]
  def change
    create_table :albums_tracks do |t|
      t.references  :album, index: false
      t.references  :track, index: false
      t.integer :position, default: 0
    end

    add_index :album_tracks, [:album_id, :track_id], :unique => true
  end
end
