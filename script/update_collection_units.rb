DB = Sequel.connect(ENV['DATABASE_URL'], max_connections: 20, pool_timeout: 10)
items = DB[:reindexing_nodes]

items.where(model: 'Admin::Collection', state: 'waiting reindex').each do |item|
  collection = Admin::Collection.find(ActiveFedora::Base.uri_to_id(item[:uri]))
  begin
    collection.unit
  rescue
    puts "Migrating unit #{collection.unit_id} for collection #{collection.id}"
    collection.unit = Admin::Unit.where(name_ssi: collection.unit_id).first
    collection.send(:_update_record, update_index: false)
  end
end
