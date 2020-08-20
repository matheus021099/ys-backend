require 'csv'
# ShopCategories.delete_all
csv_text = File.read(Rails.root.join('db', 'seeds', 'shop_categories.csv'))
csv = CSV.parse(csv_text, :headers => true)
csv.each do |row|
  category = ShopCategory.find_or_create_by!(name: row['name'])
  category.update_columns(is_digital: ActiveModel::Type::Boolean.new.cast(row['is_digital']))
  # category.touch
end
