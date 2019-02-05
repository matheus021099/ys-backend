require 'csv'
# Role.delete_all
csv_text = File.read(Rails.root.join('db', 'seeds', 'roles.csv'))
csv = CSV.parse(csv_text, :headers => true)
csv.each do |row|
  Role.find_or_create_by!(id: row['id'], name: row['name'])
end
