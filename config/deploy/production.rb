# server '54.171.75.140', user: 'deploy', roles: %w{env_primary web app migrate} # ruby-2.5.1-production-rails-1
# server '54.77.76.250', user: 'deploy', roles: %w{env_secondary web app migrate} # ruby-2.5.1-production-rails-2

# server '52.17.15.116', user: 'deploy', roles: %w{sidekiq} # sidekiq

# Extra capacity
# server '52.18.146.7', user: 'deploy', roles: %w{env_secondary web app migrate} # production-rails-3
# server '18.203.99.112', user: 'deploy', roles: %w{env_secondary web app migrate} # production-rails-4

# server '34.244.30.87', user: 'deploy', roles: %w{env_secondary web app migrate} # production-rails-5
server '54.72.17.70', user: 'deploy', roles: %w{env_secondary web app migrate} # production-rails-6

set :log_level, :debug
set :bundle_flags, '--without development test --deployment'
set :rails_env, 'production'

#set :nginx_server_name, 'www.lovetoride.net'

set :unicorn_workers, 3

set :sidekiq_pid, File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid')
set :sidekiq_processes, 4

# Once instance should have the sidekiq queues
# (strava_sync_queue can block due to rate limiting, so we don't want to bung up the whole lot)
base_queues =  %w{
  default cache_queue
  merge_organizations_and_departments
  intercom_sync_queue badges_queue
}.map{|q| "--queue #{q} "}.join(' ')

strava_queues = %w{
  strava_sync_queue
  strava_sync_coords_queue
}.map{|q| "--queue #{q} "}.join(' ')

mailchimp_queues = %w{
  mailer mailers mailchimp_sync_queue
}.map{|q| "--queue #{q} "}.join(' ')

export_queues = %w{
  export_queue
}.map{|q| "--queue #{q} "}.join(' ')

set :sidekiq_options_per_process, [
  "--concurrency 5 #{strava_queues}",
  "--concurrency 4 #{mailchimp_queues}",
  "--concurrency 10 #{base_queues}",
  "--concurrency 5 #{export_queues}"
]
# set :sidekiq_options_per_process, [
#   "--concurrency 10 #{strava_queues}",
#   "--concurrency 5 #{mailchimp_queues}",
#   "--concurrency 5 #{base_queues}"
# ]
set :sidekiq_role, :sidekiq
