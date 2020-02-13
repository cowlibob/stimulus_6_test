require 'dotenv/load'
require 'json'
# config valid only for Capistrano 3.1
lock '~> 3.11.0'

set :application, 'challenge'
set :repo_url, 'git@github.com:lovetoride/lovetoride.git'

# Default branch is :master
set :branch, ENV['BRANCH'] || 'master'
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }.call

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/srv/challenge'
set :user, 'deploy'

set :migration_role, 'migrate'

# Default value for :scm is :git
set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/database.yml config/redis.yml config/secrets.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{bin log tmp/pids tmp/cache tmp/sockets vendor/bundle}

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 2
set :keep_releases, 2

set :rvm1_ruby_version, "2.5.7"
set :rvm1_auto_script_path, '/tmp/challenge'

before 'deploy', 'rvm1:install:ruby'
before 'deploy', 'install:yarn:prerequisites'
# after 'deploy:updated', 'webpacker:precompile'
#after "deploy:updated", "newrelic:notice_deployment"

SSHKit.config.command_map.prefix[:bundle].unshift " chpst -e /srv/challenge/shared/environment"
SSHKit.config.command_map.prefix[:rake].unshift " chpst -e /srv/challenge/shared/environment"
SSHKit.config.command_map.prefix[:sidekiq].unshift " chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do"
SSHKit.config.command_map.prefix[:sidekiqctl].unshift " chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do"


# Rake::Task["webpacker:compile"].clear_actions if Rake::Task["webpacker:compile"]
# namespace :webpacker do
#   task :compile do
#     debugger
#   end
# end
# before 'deploy', 'deploy:local_webpack'
# namespace 'deploy' do
#   task :local_webpack do
#     run_locally do
#       execute('bin/rake assets:precompile RAILS_ENV=')
#     end
#   end
# end
# before "deploy:assets:precompile", "deploy:yarn_install"
# namespace :deploy do
#   desc "Run rake yarn install"
#   task :yarn_install do
#     on roles(:web) do
#       within release_path do
#         puts "cd #{release_path} && yarn install --silent --no-progress --no-audit --no-optional"
#       end
#     end
#   end
# end

namespace :sidekiq do
  desc 'Quiet sidekiq (stop processing new tasks)'
  Rake::Task["quiet"].clear_actions
  task :quiet do
    on roles(:sidekiq) do
      puts "Using pkill to send the quiet signal to sidekiq processes."
      command = create_command_and_execute([:pkill, '--signal TSTP', '-f', 'sidekiq'], {verbosity: Logger::ERROR, raise_on_non_zero_exit: false})

      output_string = case command.exit_status.to_i
      when 0
        "One or more processes were matched."
      when 1
        "No processes were matched."
      when 2
        "Invalid options were specified on the command line."
      when 3
        "An internal error occurred."
      end
      output.log_command_data(command, :stderr, output_string)
    end
  end
end

namespace :install do
  namespace :yarn do
    task :prerequisites do
      on roles(:web) do
        execute('curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -')
        execute('echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list')
        execute('curl -sL https://deb.nodesource.com/setup_13.x | sudo -E bash -')
        execute('sudo apt-get install -y nodejs')
        execute('sudo apt update && sudo apt install yarn')
        # execute("cd #{fetch(:deploy_to)}/current && exec chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do bundle exec rake webpacker:install")
      end
    end
  end
end

namespace :deploy do
  task :cleanup do
    on roles(:sidekiq) do
      within(fetch(:current_directory)) do
        puts "Custom cleanup"
        execute("chmod", "+x", "/srv/challenge/current/script/kill_removed_sidekiq_revisions.sh")
        execute("/srv/challenge/current/script/kill_removed_sidekiq_revisions.sh")
      end
    end
  end
end

namespace :rails do
  desc 'Open a rails console `cap [staging] rails:console [server_index default: 0]`'
  task :console do
    on roles(:sidekiq) do |server|
      server_index = ARGV[2].to_i

      return if server != roles(:sidekiq)[server_index]

      puts "Opening a console on: #{host}...."

      cmd = "ssh #{server.user}@#{host} -t 'cd #{fetch(:deploy_to)}/current && exec chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do bundle exec rails console #{ENV['console_options']}'"

      puts cmd

      exec cmd
    end
  end

  task :dbconsole do
    on roles(:sidekiq) do |server|
      server_index = ARGV[2].to_i

      return if server != roles(:sidekiq)[server_index]

      puts "Opening a console on: #{host}...."

      cmd = "ssh #{server.user}@#{host} -t 'cd #{fetch(:deploy_to)}/current && exec chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do bundle exec rails dbconsole #{ENV['console_options']}'"

      puts cmd

      exec cmd
    end
  end

end

desc 'Run specified rake task `cap [staging] rake_task task:name [server_index default: 0]`'
task :rake_task do
  on roles(:sidekiq) do |server|
    task_name = ARGV[2]
    env_values = ARGV[3]
    server_index = ARGV[4].to_i

    return if server != roles(:sidekiq)[server_index]

    puts "Running rake task on: #{host}...."

    cmd = "ssh #{server.user}@#{host} -t 'cd #{fetch(:deploy_to)}/current && exec chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm #{fetch(:rvm1_ruby_version)} do bundle exec rake #{task_name} #{env_values}'"

    puts cmd

    exec cmd
  end
end

namespace :unicorn do
  before :restart, 'rvm1:hook'

  desc 'Replace init.d script'
  task :clear_init_d do
    on roles(:web) do |host|
      execute('sudo', 'mv', '/etc/init.d/unicorn_challenge_production', "/etc/init.d/unicorn_challenge_production.bak.#{Time.now.strftime("%Y%m%d-%H%M%S")}")
    end
  end

  before :setup_initializer, :clear_init_d

end

namespace :env do
  desc 'Populate an env var on all servers'
  task :set_var do
    on roles(:all) do |host|
      within '/srv/challenge/shared/environment' do
        puts test("[ -f /srv/challenge/shared/environment/#{ENV['key']} ]")
        if test("[ -f /srv/challenge/shared/environment/#{ENV['key']} ]")
          execute('cp', ENV['key'], "#{ENV['key']}_#{Time.now.strftime("%F_%H-%M")}")
        end
        execute('cat', '>', ENV['key'], '<<<', ENV['value'])
      end
    end
  end

  desc 'Retrieve env var from all servers'
  task :get_var do
    on roles(:all) do |host|
      within '/srv/challenge/shared/environment' do
        puts "#{host}: #{ENV['key']} = #{capture(:cat, ENV['key'])}"
      end
    end
  end

  desc 'Duplicate keys from one app server to all others'
  task :propogate_vars do
    env_vars = {}
    on roles(:env_primary) do |host|
      within '/srv/challenge/shared/environment' do
        cmd = %q{'require "json"; puts Dir.glob("#{Dir.pwd}/*").map{|path| {key: File.basename(path), value: File.read(path).lines(chomp: true).first} }.to_json'}
        env_vars = capture(:ruby, '-e', cmd)
      end
    end

    on roles(:env_secondary) do |host|
      within '/srv/challenge/shared/environment' do
        changed = false
        JSON.parse(env_vars).each do |entry|
          puts "#{entry['key']} ----> #{entry['value']}"
          unless entry['value'].nil?
            existing = capture(:cat, entry['key']) rescue nil
            if existing != entry['value']
              puts "Was '#{existing}', should be '#{entry['value']}'"
              puts "Updating #{entry['key']} for host #{host}"
              execute(:cat, '>', entry['key'], '<<<', entry['value'] || '""')
              changed = true
            else
              puts "No change"
            end
          else
            puts "Skipped empty value for #{entry['key']}"
          end
        end

        if changed
          time = rand(5)
          puts "Rebooting in #{time}"
          # execute(:sudo, :shutdown, '-r', "+#{time}")
        end
      end
    end

  end
end

namespace :keys do
  desc 'Append public ssh key to /home/deploy/.ssh/authorized_keys on all servers'
  task :append do
    on roles(:all) do |host|
      execute("echo \"#{ENV['key']}\" >> ~/.ssh/authorized_keys")
    end
  end
end
