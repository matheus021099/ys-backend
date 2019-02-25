require 'csv'
# Genre.delete_all
csv_text = File.read(Rails.root.join('db', 'seeds', 'genres_tree.csv'))
csv = CSV.parse(csv_text, :headers => true)
csv.each do |row|
  parent_name = row['parent_name']

  # parent = parent_name.blank? ? nil : Genre.find_or_create_by!(name: parent_name, ancestry: nil)
  # genre = Genre.find_or_create_by!(name: row['name'])
  # genre.update_attributes(parent: parent)

  ancestry = parent_name.blank? ? nil : Genre.find_or_create_by!(name: parent_name).id
  genre = Genre.find_or_create_by!(name: row['name'], ancestry: ancestry)
  genre.update_attributes(color: row['color'])
end
