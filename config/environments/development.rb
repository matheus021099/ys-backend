Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.seconds.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  config.action_cable.url = 'ws://192.168.0.170:3000'
  config.action_cable.allowed_request_origins = [ 'http://localhost:8080', 'http://192.168.0.170:8080' ]

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://192.168.0.170:3000'
  # ActionController::Base.asset_host = 'http://192.168.0.170:3000'

  # mail cacher gem
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.smtp_settings = { :address => '192.168.0.170', :port => 1025 }

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.perform_deliveries = true
  # config.action_mailer.raise_delivery_errors = true
  # config.action_mailer.smtp_settings = {
  #   :address => ENV["AWS_SES_SMTP_SERVER"],
  #   :port => ENV["AWS_SES_SMTP_PORT"],
  #   :user_name => ENV["AWS_SES_SMTP_USERNAME"], #Your SMTP user
  #   :password => ENV["AWS_SES_SMTP_PASSWORD"], #Your SMTP password
  #   :authentication => :login,
  #   :enable_starttls_auto => true
  # }
end
