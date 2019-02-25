class AddColorToGenres < ActiveRecord::Migration[5.0]
  def change
    add_column :genres, :color, :string, default: ''
  end
end
