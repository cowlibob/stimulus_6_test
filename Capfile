# Load DSL and Setup Up Stages
require 'capistrano/setup'

# Includes default deployment tasks
require 'capistrano/deploy'

require 'capistrano/rails'
require 'capistrano/unicorn_nginx'

require 'capistrano/sidekiq'
# require 'capistrano/sidekiq/monit' #to require monit tasks # Only for capistrano3

require "capistrano/scm/git"
install_plugin Capistrano::SCM::Git

require 'capistrano/yarn'
# require "capistrano/webpacker/precompile"

#require 'new_relic/recipes'

# Includes tasks from other gems included in your Gemfile
#
# For documentation on these, see for example:
#
#   https://github.com/capistrano/rvm
#   https://github.com/capistrano/rbenv
#   https://github.com/capistrano/chruby
#   https://github.com/capistrano/bundler
#   https://github.com/capistrano/rails
#
require 'rvm1/capistrano3'

# require 'capistrano/rbenv'
# require 'capistrano/chruby'
# require 'capistrano/bundler'
# require 'capistrano/rails/assets'
# require 'capistrano/rails/migrations'

# Loads custom tasks from `lib/capistrano/tasks' if you have any defined.
Dir.glob('lib/capistrano/tasks/*.rake').each { |r| import r }

SSHKit.config.command_map[:bundle] = " exec chpst -e /srv/challenge/shared/environment /home/deploy/.rvm/bin/rvm 2.5.7 do bundle"
