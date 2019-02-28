class AddSequenceToGenres < ActiveRecord::Migration[5.0]
  def change
    add_column :genres, :region, :string, default: ''
    add_column :genres, :sequence, :integer, default: 0
  end
end
