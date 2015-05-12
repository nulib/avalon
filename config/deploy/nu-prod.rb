# These are the configurable bits
set(:rails_env) { "production" }
set(:deployment_host) { "avalonweb1p.library.northwestern.edu" }  # Host(s) to deploiy to
set(:deploy_to) { "/var/www/avalon" }                              # Directory to deploy into
set(:user) { 'avalon' }                                            # User to deploy as
set(:repository) { ENV['CAP_REPO'] || "git://github.com/nulib/avalon.git" }           # If not using the default avalon repo
set(:branch) { ENV['CAP_BRANCH'] || "deploy/nu-prod" }                                  # Git branch to deploy
set(:rvm_ruby_string) { "2.1.6" }
ssh_options[:keys] = [File.join(ENV["HOME"], ".ssh", "id_dsa")]    # SSH key used to authenticate as #{ user }

set :bundle_without, [:development, :test]

role :web, deployment_host
role :app, deployment_host
role :db,  deployment_host, :primary => true
