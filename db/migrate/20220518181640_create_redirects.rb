class CreateRedirects < ActiveRecord::Migration[5.2]
  def change
    create_table :redirects, id: false do |t|
      t.string :id, null: false, primary_key: true
      t.string :item_target, null: false
      t.string :embed_target, null: true
    end
  end
end
