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

describe 'checks navigation after logging in' do
  after { Warden.test_reset! }
  it 'checks navigation to Browse' do
    user = FactoryGirl.create(:administrator)
    login_as user, scope: :user
    visit '/'
    click_link('Browse')
    expect(page.current_url).to eq('http://www.example.com/catalog?q=&search_field=all_fields&utf8=%E2%9C%93')
  end
  it 'checks navigation to Manage Content' do
    user = FactoryGirl.create(:administrator)
    login_as user, scope: :user
    visit '/'
    click_link('Manage Content')
    expect(page.current_url).to eq('http://www.example.com/admin/collections')
    page.should have_content('Skip to main content')
    page.should have_link('Manage Selected Items (0)')
    page.should have_button('Create Collection')
    page.should have_content('Name')
    page.should have_content('Description')
    page.should have_content('Unit')
    page.should have_content('Default Unit')
    page.should have_link('Cancel')
  end
  it 'checks naviagtion to Manage Groups' do
    user = FactoryGirl.create(:administrator)
    login_as user, scope: :user
    visit '/'
    click_link('Manage Groups')
    expect(page.current_url).to eq('http://www.example.com/admin/groups')
    page.should have_content('System Groups')
    page.should have_content('Additional Groups')
    page.should have_content('Group Name')
    page.should have_content('group_manager')
    page.should have_content('administrator')
    page.should have_content('manager')
  end
  it 'checks naviagtion to Playlist' do
    user = FactoryGirl.create(:administrator)
    login_as user, scope: :user
    visit '/'
    click_link('Playlist')
    expect(page.current_url).to eq('http://www.example.com/playlists')
    page.should have_content('Playlists')
    page.should have_content('Create New Playlist')
  end
  it 'is able to sign out' do
    user = FactoryGirl.create(:administrator)
    login_as user, scope: :user
    visit '/'
    click_link('Sign out', match: :first)
    page.should have_content('Signed out successfully')
  end
end

describe 'Search' do
  it 'is able to enter keyword and perform search' do
    visit '/'
    fill_in('Search audio or video', with: 'Video')
    click_button 'Search audio or video'
    expect(page.current_url).to eq('http://www.example.com/catalog?utf8=%E2%9C%93&search_field=all_fields&q=Video')
  end
  it 'gives appropriate error when keyword returns no results' do
    visit '/'
    fill_in('Search audio or video', with: 'Video')
    click_button 'Search audio or video'
    page.should have_content('No results found for your search')
    page.should have_content('No entries found')
    page.should have_content('Use fewer keywords to start, then refine your search using the links on the left')
    page.should have_content('Try modifying your search')
  end
end
