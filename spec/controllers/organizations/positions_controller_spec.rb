require 'rails_helper'

RSpec.describe Organizations::PositionsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:position_level_1) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.1') }
    let!(:position_level_2) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.2') }
    let!(:position_level_3) { create(:position_level, position_major_level: position_type.position_major_level, level: '1.3') }
    let!(:position_level_4) { create(:position_level, position_major_level: position_type.position_major_level, level: '2.1') }
    
    let!(:position_v1) { create(:position, position_type: position_type, position_level: position_level_1, semantic_version: '1.0.0') }
    let!(:position_v1_2) { create(:position, position_type: position_type, position_level: position_level_2, semantic_version: '1.2.3') }
    let!(:position_v2) { create(:position, position_type: position_type, position_level: position_level_3, semantic_version: '2.0.0') }
    let!(:position_v0) { create(:position, position_type: position_type, position_level: position_level_4, semantic_version: '0.1.0') }

    it 'returns all positions when no filters applied' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:positions)).to include(position_v1, position_v1_2, position_v2, position_v0)
    end

    it 'filters by major version 1' do
      get :index, params: { organization_id: organization.id, major_version: 1 }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions).not_to include(position_v2, position_v0)
    end

    it 'filters by major version 2' do
      get :index, params: { organization_id: organization.id, major_version: 2 }
      positions = assigns(:positions)
      expect(positions).to include(position_v2)
      expect(positions).not_to include(position_v1, position_v1_2, position_v0)
    end

    it 'filters by major version 0' do
      get :index, params: { organization_id: organization.id, major_version: 0 }
      positions = assigns(:positions)
      expect(positions).to include(position_v0)
      expect(positions).not_to include(position_v1, position_v1_2, position_v2)
    end

    it 'returns empty result when filtering for non-existent major version' do
      get :index, params: { organization_id: organization.id, major_version: 99 }
      expect(assigns(:positions)).to be_empty
    end

    it 'combines major_version filter with position_type filter' do
      other_position_type = create(:position_type, organization: organization)
      other_position_level = create(:position_level, position_major_level: other_position_type.position_major_level)
      other_position = create(:position, position_type: other_position_type, position_level: other_position_level, semantic_version: '1.0.0')

      get :index, params: { organization_id: organization.id, major_version: 1, position_type: position_type.id }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions).not_to include(other_position, position_v2, position_v0)
    end

    it 'combines major_version filter with sorting' do
      get :index, params: { organization_id: organization.id, major_version: 1, sort: 'name' }
      positions = assigns(:positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions.length).to eq(2)
    end
  end
end

