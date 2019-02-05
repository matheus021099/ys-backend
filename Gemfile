source 'https://rubygems.org'
ruby '~> 2.4.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.0.1'
gem 'pg', '~> 0.18'
gem 'puma', '~> 3.7'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.5'
# Use Redis adapter to run Action Cable in production
gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

gem 'newrelic_rpm'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem 'rack-cors'
gem 'rack-attack'

# use javascript web token
gem 'jwt'

gem 'stripe'
# gem 'twitter'
# user authenticate
gem 'devise'
gem 'omniauth'
gem 'omniauth-stripe-connect'
gem 'omniauth-twitter'
# check authorization on action
gem 'pundit'
# define authorization on db
gem 'rolify'

gem 'bulk_insert'

# API serializer
gem 'active_model_serializers'

# file upload
gem 'carrierwave'
# image resize
gem 'mini_magick'
# cloud front
gem 'cloudfront-signer'
# cloud server management
gem 'fog'
# stream dynamically generated zip
gem 'zip_tricks'
gem 'zipline'

# audio fingerprinting
gem 'openssl'
gem 'audio-trimmer'

# cronjob
gem 'sidekiq'
gem 'sidekiq-unique-jobs'
gem 'clockwork', github: 'Rykian/clockwork'

# relate to model
# gem 'delayed_job'
# gem 'delayed_job_active_record'
gem 'acts-as-taggable-on'
# gem 'acts_as_follower'
gem 'acts_as_follower', github: 'tcocca/acts_as_follower', branch: 'master'
gem 'ancestry'
gem 'mailboxer'
# enable to use slug
gem 'friendly_id'
# pagination
gem 'kaminari'
# define env file
gem 'dotenv-rails'
# use faker to seed
gem 'faker'
# mailgun to send email
# gem 'mailgun_rails'
# enable elastic-search
gem 'searchkick'

gem 'countries'
gem 'slim-rails'
gem 'swagger-docs'

gem 'aws-sdk', '~> 3'
gem 'aws-sdk-medialive', '~> 1.5.0'

gem 'foreman'

# gem 'curb'
# gem 'down'

group :development, :test do
  # capistrano
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-puma'
  gem 'capistrano-rbenv'
  # gem 'capistrano-rbenv-install'
  gem 'capistrano-foreman-systemd'

  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'rb-readline'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
