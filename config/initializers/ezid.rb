require 'ezid-client'

unless Ezid::Client.config.default_shoulder.nil?
  Avalon::Permalink.on_generate do |obj, url|
    metadata = {
      '_target' => url,
      'datacite.location' => url,
      'datacite.title' => obj.title,
      'datacite.creator' => obj.creator.empty? ? 'Unknown' : obj.creator.join('; '),
      'datacite.publisher' => obj.publisher.empty? ? 'Unknown' : obj.publisher.join('; '),
      'datacite.publicationyear' => obj.date_issued || obj.date_created || obj.copyright_date || obj.create_date.strftime('%Y-%m-%d'),
      'datacite.resourcetype' => 'Audiovisual'
    }
    identifier = Ezid::Identifier.mint(metadata)
    doi = identifier.id.split(/:/).last
    "https://doi.org/#{doi}"
  end
end
