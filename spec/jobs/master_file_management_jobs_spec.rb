# Copyright 2011-2018, The Trustees of Indiana University and Northwestern
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

require 'rails_helper'
require 'fakefs/safe'

describe MasterFileManagementJobs do

  context "fakefs" do

    before :each do
      @oldpath = "/path/to/old/file.mp4"
      @mf = FactoryGirl.build(:master_file)
      @mf.file_location = @oldpath
      @mf.save
      FakeFS.activate!
      FileUtils.mkdir_p File.dirname(@oldpath)
      File.open(@oldpath, 'w'){}
    end

    describe "delete_masterfile" do
      it "should delete masterfile" do
        MasterFileManagementJobs::Delete.perform_now(@mf.id)
        expect(File.exists? @oldpath).to be false
        expect(MasterFile.find(@mf.id).file_location).to be_blank
      end
    end

    describe "move_masterfile" do
      it "should move masterfile" do
        newpath = "/path/to/new/file.mp4"
        MasterFileManagementJobs::Move.perform_now(@mf.id, newpath)
        expect(File.exists? @oldpath).to be false
        expect(File.exists? newpath).to be true
        expect(newpath).to eq MasterFile.find(@mf.id).file_location
      end
    end

    after :each do
      FakeFS.deactivate!
    end
  end
end
