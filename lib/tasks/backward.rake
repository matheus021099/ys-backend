namespace :db do
  desc "Do backward compatibility"
  task :backward => :environment do
    puts 'Start backward compatibility...'
    Rake::Task['db:album'].execute
    Rake::Task['db:product'].execute
    puts 'Done backward'
  end

  desc 'Generate users_albums based on albums'
  task :album => :environment do
    puts 'Start generating users_albums based on albums...'
    albums = Album.where('user_id IS NOT NULL')
    albums.each do |album|
      UserAlbum.find_or_create_by!(
        user_id: album.user_id,
        album_id: album.id,
        user_type: UserAlbum.user_types[:creator]
      )
    end
    puts 'Done generating users_albums'
  end

  desc 'Generate users_products based on products'
  task :product => :environment do
    puts 'Start generating users_products based on products...'
    products = ShopProduct.where('merchant_id IS NOT NULL')
    products.each do |product|
      UserProduct.find_or_create_by!(
        user_id: product.merchant_id,
        product_id: product.id,
        user_type: UserProduct.user_types[:creator]
      )
    end
    puts 'Done generating users_products'
  end

  desc 'Fill order_id in payments'
  task :payment => :environment do
    puts 'Start filling order_id in payments'
    Payment.where(assoc_type: 'ShopOrder').update_all("order_id = assoc_id, assoc_type = NULL, assoc_id = NULL")
    puts 'Done filling order_id'
  end

  desc 'Convert payment stream datetime 2018-11-11 11:11:11 UTC -> 11:11:11 Nov 11, 2018'
  task :convert_payment_stream_datetime => :environment do
    puts 'Start converting payment stream datetime...'
    Payment.where(payment_type: Payment.payment_types[:stream]).each do |payment|
      desc = payment.description
      str_date = desc.slice!(-23, 23)
      date = DateTime.parse(str_date) rescue nil
      if date
        desc += date.strftime("%H:%M:%S %b %d, %Y")
        payment.update_columns(description: desc)
      end
    end
    puts 'Done'
  end
end
