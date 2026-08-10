#!/usr/bin/env ruby
# frozen_string_literal: true

# Walks an OCFL root looking for .nt files containing hasModel triples like:
#
#   <info:fedora/avr/50/ff/c3/30/50ffc330-64fe-4dd2-a534-72112ede437d> <info:fedora/fedora-system:def/model#hasModel> "Hydra::AccessControl" .
#
# and inserts a row per match into the reindexing_nodes table (same schema used by reindex.rb):
#
#   uri, model, updated_at, state ("waiting reindex"), state_changed_at
#
# The tree is walked lazily (Find.find) by a single producer thread that feeds paths into a
# Queue, so processing starts on the first .nt file found instead of blocking on a Dir.glob
# of the whole tree up front -- with 150k+ files under the root that upfront glob is itself
# a slow, memory-heavy stat storm. Worker threads consume the queue via Parallel.each; since
# each thread's work is dominated by DB I/O (batch inserts) rather than CPU, Ruby threads
# parallelize this fine despite the GIL.
#
# Usage: bundle exec ruby script/hasmodel_to_db.rb [options]

require 'find'
require 'optparse'
require 'parallel'
require 'sequel'
require 'time'

options = { threads: 10, batch_size: 500 }
OptionParser.new do |parser|
  parser.banner = "Usage: bundle exec ruby script/hasmodel_to_db.rb [options]"

  parser.on("-d", "--database URL", "Database connection url (defaults to $DATABASE_URL)") do |d|
    options[:database_url] = d
  end

  parser.on("-f", "--fedora-url URL", "Fedora base url (defaults to $FEDORA_URL)") do |f|
    options[:fedora_url] = f
  end

  parser.on("-o", "--ocfl-root PATH", "OCFL root path (defaults to $OCFL_ROOT)") do |o|
    options[:ocfl_root] = o
  end

  parser.on("-t", "--threads N", Integer, "Number of files to process concurrently (default: 10)") do |t|
    options[:threads] = t
  end

  parser.on("-b", "--batch-size N", Integer, "Rows per DB insert batch (default: 500)") do |b|
    options[:batch_size] = b
  end

  parser.on("-v", "--verbose", "Verbose logging") do |v|
    options[:verbose] = v
  end

  parser.on("-h", "--help", "Prints this help") do
    puts parser
    exit
  end
end.parse!

if (!options[:ocfl_root])
  puts "OCFL root path is required (use -o or set $OCFL_ROOT)"
  exit 1
end

fedora_url = options[:fedora_url] || ENV.fetch('FEDORA_URL')
fedora_url = URI.parse(fedora_url)
fedora_url.user = nil
fedora_url.password = nil
fedora_url = fedora_url.to_s.chomp('/')

database_url = options[:database_url] || ENV.fetch('DATABASE_URL')
DB = Sequel.connect(database_url, max_connections: options[:threads] + 2, pool_timeout: 10)

unless DB.tables.include?(:reindexing_nodes)
  DB.create_table :reindexing_nodes do
    primary_key :id
    String :uri
    String :model
    DateTime :updated_at
    String :state
    DateTime :state_changed_at
    index :uri
    index :state
    index :state_changed_at
    index [:uri, :state]
  end
end
items = DB[:reindexing_nodes]

HAS_MODEL_LINE = /\A<info:fedora(\/[^>]*)>.*"([^"]*)"/

# Yields a { uri:, model:, updated_at:, state:, state_changed_at: } hash for each hasModel
# triple found in path. Pre-filtering with String#include? (a fast C substring search) before
# running the regex keeps this close to ripgrep's speed without shelling out.
def each_hasmodel_match(path, fedora_url)
  timestamp = Time.now.utc
  File.foreach(path, encoding: 'BINARY') do |line|
    next unless line.include?('hasModel')
    next unless (match = HAS_MODEL_LINE.match(line))

    yield(
      uri: "#{fedora_url}#{match[1]}",
      model: match[2],
      updated_at: timestamp,
      state: "waiting reindex",
      state_changed_at: timestamp
    )
  end
end

# Producer: walks the tree depth-first and pushes matching paths as it finds them, rather
# than collecting the whole 150k+-entry tree into an array before any work can start.
paths = Queue.new
producer = Thread.new do
  Find.find(options[:ocfl_root]) do |path|
    paths << path if path.end_with?('.nt') && File.file?(path)
  end
  paths << Parallel::Stop
end
producer.abort_on_exception = true

# Consumers: Parallel recognizes a Queue (responds to #num_waiting/#pop) as a producer source
# and pulls from it with a blocking pop, so workers start as soon as the first path arrives.
Parallel.each(paths, in_threads: options[:threads]) do |path|
  batch = []
  count = 0

  each_hasmodel_match(path, fedora_url) do |row|
    batch << row
    if batch.size >= options[:batch_size]
      items.multi_insert(batch)
      count += batch.size
      batch.clear
    end
  end

  unless batch.empty?
    items.multi_insert(batch)
    count += batch.size
  end

  puts "#{Time.now.utc} #{path}: inserted #{count} rows" if options[:verbose]
end

producer.join
