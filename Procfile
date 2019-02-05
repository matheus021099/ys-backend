web:     bin/bundle exec puma -C config/puma.rb
worker0: bin/bundle exec sidekiq -C config/sidekiq.yml --index 0 -e production --logfile log/sidekiq.0.log
clock:   bin/bundle exec clockwork config/clock.rb
