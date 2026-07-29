# AVR development convenience: `bundle exec guard -i` brings up the web app and
# a background worker together, restarting both when app code changes.
#
# See docs/AVR_DEVELOPMENT.md.

group :webapp do
  guard 'puma' do
    watch('Gemfile.lock')
    watch(%r{^(app|config|lib|api)/.*})
  end
end

group :worker do
  # Matches production: AVR's ActiveJob adapter is Shoryuken, not Sidekiq
  # (see config/application.rb). Needs SQS queues to exist first:
  #
  #   bundle exec rake shoryuken:create_config shoryuken:create_queues
  guard 'process', name: 'shoryuken', command: 'bundle exec shoryuken --config=config/shoryuken.yml --rails' do
    watch('Gemfile.lock')
    watch(%r{^(app|config|lib|api)/.*})
  end
end
