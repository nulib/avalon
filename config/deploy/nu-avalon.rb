# These are the configurable bits
set(:rails_env)       { ENV['RAILS_ENV'] || "production" }
set(:deployment_host) { ENV['AVALON_HOST'] || "localhost" }                          # Host(s) to deploiy to
set(:deploy_to)       { "/var/www/avalon" }                                          # Directory to deploy into
set(:user)            { 'avalon' }                                                   # User to deploy as
set(:repository)      { ENV['AVALON_REPO'] || "git://github.com/nulib/avalon.git" }  # If not using the default avalon repo
set(:branch)          { ENV['AVALON_BRANCH'] || "deploy/nu-staging" }                # Git branch to deploy
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_dsa"),'/opt/staging/avalon/deployment_key']    # SSH key used to authenticate as #{ user }

set :bundle_without, [:development, :test]

role :web, deployment_host
role :app, deployment_host
role :db,  deployment_host, :primary => true
