namespace :avr do
  desc "Prepare the AVR environment"
  task :setup do
    ['zookeeper:upload', 'zookeeper:create', 'db:create', 'db:migrate'].each do |task|
      Rake::Task[task].invoke
    end

    ActiveFedora.fedora.connection.tap do |conn|
      conn.head(conn.root_resource_path)
    end

    begin
      Rake::Task['avalon:reindex'].invoke
    rescue
    end
  end

  desc "Completely reset the AVR environment"
  task :reset do
    Rake::Task['avr:setup'].invoke

    ENV['CONFIRM'] = 'yes'
    $stderr.puts("Wiping DB, Fedora, Solr, and Redis")
    Rake::Task['avalon:wipeout'].invoke
    
    $stderr.puts("Emptying derivatives bucket")
    Aws::S3::Bucket.new(Settings.encoding.derivative_bucket).objects.each(&:delete)
    $stderr.puts("Emptying masterfiles bucket")
    Aws::S3::Bucket.new(Settings.encoding.masterfile_bucket).objects.each(&:delete)

    $stderr.puts("Recreating Fedora root resource path")
    ActiveFedora.fedora.connection.tap do |conn|
      conn.head(conn.root_resource_path)
    end
  end
end