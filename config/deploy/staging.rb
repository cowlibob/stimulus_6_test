# Simple Role Syntax
# ==================
# Supports bulk-adding hosts to roles, the primary server in each group
# is considered to be the first unless any hosts have the primary
# property set.  Don't declare `role :all`, it's a meta role.

#role :app, %w{ubuntu@challenge-production-rails-1-eu}
#role :web, %w{ubuntu@ec2-54-76-104-64.eu-west-1.compute.amazonaws.com}
#role :db,  %w{ubuntu@ec2-54-76-104-64.eu-west-1.compute.amazonaws.com}


# Extended Server Syntax
# ======================
# This can be used to drop a more detailed server definition into the
# server list. The second argument is a, or duck-types, Hash and is
# used to set extended properties on the server.

# server '54.154.35.61', user: 'deploy', roles: %w{web app migrate sidekiq}
server '18.202.241.60', user: 'deploy', roles: %w{web app migrate sidekiq}

set :log_level, :debug
set :bundle_flags, '--without development test --deployment'
set :rails_env, 'staging'

set :nginx_server_name, 'ec2-54-154-35-61.eu-west-1.compute.amazonaws.com'

set :sidekiq_pid, File.join(shared_path, 'tmp', 'pids', 'sidekiq.pid')

##########
set :sidekiq_processes, 2

# Once instance should have the sidekiq queues
# (strava_sync_queue can block due to rate limiting, so we don't want to bung up the whole lot)
base_queues =  %w{
  default mailer cache_queue export_queue intercom_sync_queue mailchimp_sync_queue
  merge_organizations_and_departments badges_queue
}.map{|q| "--queue #{q} "}.join(' ')

strava_queues = %w{
  strava_sync_queue
  strava_sync_coords_queue
}.map{|q| "--queue #{q} "}.join(' ')

set :sidekiq_options_per_process, [
  "--concurrency 1 #{strava_queues}",
  "--concurrency 2 #{base_queues}"
]

set :sidekiq_role, :sidekiq
