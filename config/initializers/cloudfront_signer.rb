# if Rails.env.production?
#   Aws::CF::Signer.configure do |config|
#     config.key = ENV['AWS_CLOUDFRONT_PRIVATE_KEY']
#     config.key_pair_id = ENV['AWS_CLOUDFRONT_KEY_PAIR_ID']
#     config.default_expires = 3600
#   end
# end
