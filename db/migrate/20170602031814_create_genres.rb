class CreateGenres < ActiveRecord::Migration[5.0]
  def change
    create_table :genres do |t|
      t.string :name
      t.text :description
      t.integer :position, default: 0

      t.string :slug
      t.string :ancestry
    end

    add_index :genres, :slug, unique: true
    add_index :genres, :ancestry
  end
end
