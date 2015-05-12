require 'bundler/setup'
require "rvm/capistrano"
require 'bundler/capistrano'
require 'whenever/capistrano'

set :application, "avalon"
set :repository,  "git://github.com/avalonmediasystem/avalon.git"

set :stages, %W(nu-test nu-prod nu-avalon)
set :default_stage, "nu-test"
require 'capistrano/ext/multistage'

set(:whenever_command) { "bundle exec whenever" }
set(:bundle_flags) { "--quiet --path=#{deploy_to}/shared/gems" }
#set :rvm_ruby_string, "2.1.4"
set :rvm_type, :system
set :rvm_path, '/usr/local/rvm'

after :bundle_install, "deploy:migrate"
before "deploy:finalize_update", "deploy:remove_symlink_targets"
after "deploy:create_symlink", "deploy:trust_rvmrc"
if ENV['AVALON_REINDEX']
  after "deploy:create_symlink", "deploy:reindex_everything"
end

set(:shared_children) {
  %{
    config/authentication.yml
    config/avalon.yml
    config/controlled_vocabulary.yml
    config/database.yml
    config/fedora.yml
    config/handle_config.yml
    config/lti.yml
    config/matterhorn.yml
    config/minter_state.yml
    config/role_map_#{fetch(:rails_env)}.yml
    config/secrets.yml
    config/solr.yml
    config/initializers/group_ldap.rb
    log
    tmp/pids
  }.split
}

set :scm, :git
set :use_sudo, false
set :keep_releases, 3

task :uname do
  run "uname -a"
end

namespace :deploy do
  task :remove_symlink_targets do
    shared_children.each do |target|
      t = File.join(latest_release,target)
      s = File.join(shared_path,File.basename(target))
      run "if [ -f #{t} ] && [ -f #{s} ]; then rm -rf #{t}; fi" unless t == latest_release
    end
  end

  task :trust_rvmrc do
    run "/usr/local/rvm/bin/rvm rvmrc trust #{latest_release}"
  end

  task :start do
    run "cd #{current_release} && RAILS_ENV=#{rails_env} bundle exec rake delayed_job:start"
  end

  task :stop do
    run "cd #{current_release} && RAILS_ENV=#{rails_env} bundle exec rake delayed_job:stop"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    run "cd #{current_release} && RAILS_ENV=#{rails_env} bundle exec rake delayed_job:restart"
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  task :reindex_everything do
    run "cd #{current_release} && RAILS_ENV=#{rails_env} bundle exec rails runner 'ActiveFedora::Base.reindex_everything'"
  end
end
