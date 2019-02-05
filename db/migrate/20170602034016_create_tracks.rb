class CreateTracks < ActiveRecord::Migration[5.0]
  def change
    create_table :tracks do |t|
      t.references :user, index: true
      t.references :album, index: true
      t.string :name
      t.string :slug
      t.text :description

      t.string :audio
      t.string :clip
      t.string :acr_id

      t.integer :played, default: 0
      t.integer :downloaded, default: 0

      t.string :status
      t.timestamps
    end

    add_index :tracks, :slug, unique: true
  end
end