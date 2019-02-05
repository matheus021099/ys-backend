require 'csv'
# Genre.delete_all
csv_text = File.read(Rails.root.join('db', 'seeds', 'genres.csv'))
csv = CSV.parse(csv_text, :headers => true)
csv.each do |row|
  Genre.find_or_create_by!(name: row['name'])
end
