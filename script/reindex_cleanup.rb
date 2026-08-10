DB = Sequel.connect(ENV['DATABASE_URL'], max_connections: 20, pool_timeout: 10)
items = DB[:reindexing_nodes]

def update_state(id, state)
  DB[:reindexing_nodes].where(id: id).update(state: state, state_changed_at: Time.now)
end

items.where(state: 'errored').each do |item|
  model = item[:model].constantize
  id = ActiveFedora::Base.uri_to_id(item[:uri])
  puts "Reindexing #{model} #{id}"
  update_state(item[:id], 'pending')
  begin
    model.find(id).update_index
    update_state(item[:id], 'processed')
  rescue => e
    puts "Error reindexing #{model} #{id}: #{e.message}"
    update_state(item[:id], 'errored')
  end
end
