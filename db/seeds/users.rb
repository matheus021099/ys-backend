superadmin = User.find_by_email('yousoundready@gmail.com')
unless superadmin.present?
  superadmin = User.create(
    email: 'yousoundready@gmail.com',
    password: 'j0_T>#GTj01Al_|#',
    username: 'superadmin',
    user_type: 'superadmin',
    display_name: 'SuperAdmin',
    first_name: 'Super',
    last_name: 'Admin',
    confirmed_at: Time.now,
    status: User.statuses[:active]
  )
end

admin1 = User.find_by_email('xinyou1003@gmail.com')
unless admin1.present?
  admin1 = User.create(
    email: 'xinyou1003@gmail.com',
    password: 'password',
    username: 'xinyou',
    user_type: 'admin',
    display_name: 'Xin You',
    first_name: 'Xin',
    last_name: 'You',
    confirmed_at: Time.now,
    status: User.statuses[:active]
  )
end

admin2 = User.find_by_email('hello@yousound.com')
unless admin2.present?
  admin2 = User.create(
    email: 'hello@yousound.com',
    password: '4Ok64:G-Ki[Jn;SI',
    username: 'frontline_general',
    user_type: 'admin',
    display_name: 'Admin',
    first_name: 'Frontline',
    last_name: 'General',
    confirmed_at: Time.now,
    status: User.statuses[:active]
  )
end

artist1 = User.find_by_email('tsgold8899@gmail.com')
unless artist1.present?
  artist1 = User.create(
    email: 'tsgold8899@gmail.com',
    password: 'password',
    username: 'mingyao',
    user_type: 'artist',
    display_name: 'Ming Yao',
    first_name: 'Ming',
    last_name: 'Yao',
    confirmed_at: Time.now,
    status: User.statuses[:active]
  )
end
