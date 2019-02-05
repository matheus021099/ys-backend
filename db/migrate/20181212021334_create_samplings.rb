class CreateSamplings < ActiveRecord::Migration[5.0]
  def change
    create_table :samplings do |t|
      t.references :sampling_user, references: :user, type: :uuid
      t.references :sampling_album, references: :album, index: true,  type: :uuid
      t.references :sampling_track, references: :track, type: :uuid

      t.references :sample_user, references: :user, type: :uuid
      t.references :sample_album, references: :album, index: true, type: :uuid
      t.references :sample_track, references: :track, type: :uuid

      # sampling_track_position
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :samplings, [:sampling_album_id, :sampling_track_id]
    add_index :samplings, [:sample_album_id, :sample_track_id]
  end
end
