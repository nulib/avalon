# AVR: table behind ApplicationController#maybe_redirect.
#
# if_not_exists because this table predates the migration: it was created by
# hand in staging and production before anyone wrote one, so those databases
# already have it. New environments (development, test, CI) get it from here.
class CreateRedirects < ActiveRecord::Migration[8.0]
  def change
    create_table :redirects, id: false, if_not_exists: true do |t|
      # Not a NOID column: keys are whatever identifier the old system used --
      # a v4/v5 Avalon id, a collection name, a legacy PID.
      t.string :id, null: false, primary_key: true
      t.string :item_target, limit: 1024
      t.string :embed_target, limit: 1024

      t.timestamps
    end
  end
end
