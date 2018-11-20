#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2018 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'
require 'rack/test'

describe 'API v3 Grids resource', type: :request, content_type: :json do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  shared_let(:current_user) do
    FactoryBot.create(:user)
  end

  before do
    login_as(current_user)
  end

  subject(:response) { last_response }

  describe '#get INDEX' do
    let(:path) { api_v3_paths.grids }
    shared_let(:my_page_grid) do
      MyPageGrid.new_default(current_user).save
    end
    shared_let(:other_user) do
      FactoryBot.create(:user)
    end
    shared_let(:other_my_page_grid) do
      MyPageGrid.new_default(other_user).save
    end

    let(:stored_grids) do
      my_page_grid
      other_my_page_grid
    end

    before do
      stored_grids

      get path
    end

    it 'responds with 200 OK' do
      expect(subject.status).to eq(200)
    end

    it 'sends a collection of grids but only those visible to the current user' do
      expect(subject.body)
        .to be_json_eql('Collection'.to_json)
        .at_path('_type')

      expect(subject.body)
        .to be_json_eql('Grid'.to_json)
        .at_path('_embedded/elements/0/_type')

      expect(subject.body)
        .to be_json_eql(1.to_json)
        .at_path('total')
    end

    context 'with a filter on the page attribute' do
      shared_let(:other_grid) do
        grid = Grid.new(row_count: 20,
                        column_count: 20)
        grid.save

        Grid.where(id: grid.id).update_all(user_id: current_user.id)

        grid
      end

      let(:stored_grids) do
        my_page_grid
        other_my_page_grid
        other_grid
      end

      let(:path) do
        filter = [{ 'page' =>
                    {
                      'operator' => '=',
                      'values' => [my_page_path]
                    } }]

        "#{api_v3_paths.grids}?#{{ filters: filter.to_json }.to_query}"
      end

      it 'responds with 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'sends only the my page of the current user' do
        expect(subject.body)
          .to be_json_eql('Collection'.to_json)
          .at_path('_type')

        expect(subject.body)
          .to be_json_eql('Grid'.to_json)
          .at_path('_embedded/elements/0/_type')

        expect(subject.body)
          .to be_json_eql(1.to_json)
          .at_path('total')
      end
    end
  end

  describe '#get' do
    let(:path) { api_v3_paths.grid(42) }

    before do
      get path
    end

    it 'responds with 200 OK' do
      expect(subject.status).to eq(200)
    end

    it 'sends a grid block' do
      expect(subject.body)
        .to be_json_eql('Grid'.to_json)
        .at_path('_type')
    end

    it 'identifies the url the grid is stored for' do
      expect(subject.body)
        .to be_json_eql(my_page_path.to_json)
        .at_path('_links/page/href')
    end
  end

  describe '#patch' do
    let(:path) { api_v3_paths.grid(42) }

    let(:params) do
      {
        "rowCount": 10,
        "columnCount": 15
      }.with_indifferent_access
    end

    before do
      patch path, params.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    it 'responds with 200 OK' do
      expect(subject.status).to eq(200)
    end

    it 'sends a grid block' do
      expect(subject.body)
        .to be_json_eql('Grid'.to_json)
        .at_path('_type')
    end

    it 'returns the altered grid block' do
      expect(subject.body)
        .to be_json_eql(params['rowCount'].to_json)
        .at_path('rowCount')
    end
  end

  describe '#post' do
    let(:path) { api_v3_paths.grids }

    let(:params) do
      {
        "rowCount": 10,
        "columnCount": 15
      }.with_indifferent_access
    end

    before do
      post path, params.to_json, 'CONTENT_TYPE' => 'application/json'
    end

    it 'responds with 201 CREATED' do
      expect(subject.status).to eq(201)
    end

    it 'returns the created grid block' do
      expect(subject.body)
        .to be_json_eql('Grid'.to_json)
        .at_path('_type')
      expect(subject.body)
        .to be_json_eql(params['rowCount'].to_json)
        .at_path('rowCount')
    end

    it 'persists the grid' do
      expect(Grid.count)
        .to eql(1)
    end
  end
end
