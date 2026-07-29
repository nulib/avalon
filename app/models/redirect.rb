# AVR: maps an identifier from a retired system onto the URL that now serves it.
#
# When AVR content moves elsewhere -- most of it to Digital Collections -- the
# old AVR URLs stay in syllabi, course sites, and citations. A row here makes
# any request for that id redirect instead of 404ing.
#
# The primary key is a string, and it is not necessarily a NOID: it can be a
# v4/v5 Avalon id, a legacy PID, or a collection name (CatalogController matches
# collection facet values against it).
#
# `item_target` is where a normal request goes; `embed_target` is where an
# /embed request goes. Rows are loaded in bulk out of band, not through the UI.
class Redirect < ApplicationRecord
  validates :item_target, presence: true
end
