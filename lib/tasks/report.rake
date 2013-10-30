# Copyright 2011-2013, The Trustees of Indiana University and Northwestern
#   University.  Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
# 
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed 
#   under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
#   CONDITIONS OF ANY KIND, either express or implied. See the License for the 
#   specific language governing permissions and limitations under the License.
# ---  END LICENSE_HEADER BLOCK  ---

require 'csv'
require 'fileutils'

namespace :avalon do
  namespace :report do
    desc "Generate a transcoding report"
    task :transcoding => [:environment] do |t,args|
      FileUtils.mkdir_p File.join(Rails.root, 'report')
      MasterFile.all.each do |mf|
        sanitized_pid = mf.pid.sub(/:/,'_')
        report_file = File.join(Rails.root,'report',"#{sanitized_pid}.txt")
        $stderr.print "Writing workflow details for #{mf.pid} to #{report_file}"
        data = mf.workflow_stats
        CSV.open(report_file,'wb',col_sep: "\t") do |csv|
          data.each do |step|
            started   = step[:started]   || 'n/a'
            completed = step[:completed] || 'n/a'
            duration  = Time.at(step[:duration]).utc.strftime('%H:%M:%S') rescue 'n/a'
            csv << [step[:operation], step[:state], started, completed, duration]
            $stderr.print "."
          end
        end
        $stderr.puts
      end
    end
  end
end
