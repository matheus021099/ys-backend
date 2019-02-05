# config valid only for current version of Capistrano
lock '3.4.1'

set :application, 'yousound'
set :repo_url, 'git@github.com:yousound/api.git'
set :deploy_user, 'ubuntu'

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/home/#{fetch(:deploy_user)}/#{fetch(:application)}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml", ".env"
set :linked_files, fetch(:linked_files, []).push('.env', 'config/puma.rb')

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets')

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 5

set :foreman_systemd_app, -> { fetch(:application) }
set :foreman_systemd_user, -> { fetch(:deploy_user) }
set :foreman_systemd_flags, "--root=#{current_path}"

# set :rbenv_type, :system
set :rbenv_ruby, '2.4.1'
set :rbenv_roles, :all
# set :rbenv_custom_path, '/usr/local/rbenv'
set :clockwork_file, 'config/clock.rb'

fetch(:rbenv_map_bins, []).push 'foreman'
fetch(:bundle_bins, []).push 'foreman'

set :bundle_binstubs, nil

after 'deploy:publishing', 'foreman_systemd:restart'
#after 'deploy:restart', 'foreman_systemd:restart'

# namespace :deploy do
#   desc 'Restart application'
#   task :restart do
#     on roles(:app), in: :sequence, wait: 5 do
#       execute :touch, release_path.join('tmp/restart.txt')
#       within "#{current_path}" do
#         execute :rake, 'swagger:docs'
#       end
#     end
#   end
#   after :publishing, 'deploy:restart'
#   after :finishing, 'deploy:cleanup'
# end

# namespace :puma do
#   desc 'Create Directories for Puma Pids and Socket'
#   task :make_dirs do
#     on roles(:app) do
#       execute "mkdir #{shared_path}/tmp/sockets -p"
#       execute "mkdir #{shared_path}/tmp/pids -p"
#     end
#   end
#   before :start, :make_dirs
# end

# namespace :deploy do
#   desc 'Initial Deploy'
#   task :initial do
#     on roles(:app) do
#       before 'deploy:restart', 'puma:start'
#       invoke 'deploy'
#     end
#   end
#   desc 'Restart application'
#   task :restart do
#     on roles(:app), in: :sequence, wait: 5 do
#       invoke 'puma:restart'
#     end
#   end
#   after  :finishing,    :cleanup
#   after  :finishing,    :restart
# end
