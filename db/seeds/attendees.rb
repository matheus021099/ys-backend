require 'csv'

csv_rows = CSV.read(Rails.root.join('db', 'seeds', 'attendees.csv'), headers: true)
csv_rows.each do |row|
  Attendee.create(
    full_name: row['full_name'],
    display_name: row['display_name'],
    email: row['email'],
    account_type: row['account_type'],
    referred_by: row['referred_by']
  )
end
