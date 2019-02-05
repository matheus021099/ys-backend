class CreateAlbums < ActiveRecord::Migration[5.0]
  def change
    create_table :albums do |t|
      t.references :user, index: true
      t.string :name
      t.string :slug
      t.text :description
      t.string :artist_name
      t.string :cover # cover url
      t.integer :album_type # 0-Album, 1-Playlist, etc

      t.string :zip # album zip url
      t.datetime :zipped_at

      t.boolean :recommended
      t.datetime :recommended_at

      t.boolean :released
      t.datetime :released_at

      t.integer :played, default: 0
      t.integer :downloaded, default: 0
      t.integer :reposted, default: 0
      t.integer :commented, default: 0

      t.string location, default: ''
      t.integer :collaborators_count, default: 0
      t.boolean :enabled_sample, default: false
      t.boolean :is_only_for_live_stream, default: false

      t.boolean :is_content_acapella, default: false
      t.boolean :is_content_instrumental, default: false
      t.boolean :is_content_stems, default: false
      t.boolean :is_content_remix, default: false
      t.boolean :is_content_dj_mix, default: false

      t.string :status
      t.timestamps
    end

    add_index :albums, :slug, unique: true
  end
end
