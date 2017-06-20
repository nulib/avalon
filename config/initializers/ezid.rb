unless ENV['EZID_DEFAULT_SHOULDER'].nil?
  require 'ezid-client'

  Permalink.on_generate do |obj, url|
    mo = case obj
    when MediaObject then obj
    when MasterFile then obj.media_object
    else raise ArgumentError, "Cannot mint an ARK for #{obj.inspect}"
    end

    metadata = {
      '_export'  => mo.read_groups.include?('public') ? 'yes' : 'no',
      '_target'  => url,
      'ecc.who'  => mo.creator.empty? ? 'Unknown' : mo.creator.join('; '),
      'ecc.what' => obj.title || mo.title,
      'ecc.when' => mo.date_issued || mo.date_created || mo.copyright_date || mo.create_date.strftime('%Y-%m-%d')
    }
    identifier = Ezid::Identifier.mint(metadata)
    "http://n2t.net/#{identifier.to_s}"
  end
end
