require File.join(Rails.root, 'app/models/master_file')

class MasterFile
  def self.post_processing_move_filename(oldpath, options = {})
    prefix = ActiveFedora::Noid.treeify(options[:id].tr(':', '_'))
    if File.basename(oldpath).start_with?(prefix)
      File.basename(oldpath)
    else
      "#{prefix}/#{File.basename(oldpath)}"
    end
  end
end
