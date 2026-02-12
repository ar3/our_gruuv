require 'rails_helper'

RSpec.describe 'Organizations::Positions', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/positions' do
    let!(:position_level_1) { create(:position_level, position_major_level: title.position_major_level, level: '1.1') }
    let!(:position_level_2) { create(:position_level, position_major_level: title.position_major_level, level: '1.2') }
    let!(:position_level_3) { create(:position_level, position_major_level: title.position_major_level, level: '1.3') }
    let!(:position_level_4) { create(:position_level, position_major_level: title.position_major_level, level: '2.1') }
    
    let!(:position_v1) { create(:position, title: title, position_level: position_level_1, semantic_version: '1.0.0') }
    let!(:position_v1_2) { create(:position, title: title, position_level: position_level_2, semantic_version: '1.2.3') }
    let!(:position_v2) { create(:position, title: title, position_level: position_level_3, semantic_version: '2.0.0') }
    let!(:position_v0) { create(:position, title: title, position_level: position_level_4, semantic_version: '0.1.0') }

    it 'filters by major version 1' do
      get organization_positions_path(organization, major_version: 1)
      expect(response).to have_http_status(:success)
      positions = controller.instance_variable_get(:@positions)
      expect(positions).to include(position_v1, position_v1_2)
      expect(positions).not_to include(position_v2, position_v0)
    end

    it 'filters by major version 2' do
      get organization_positions_path(organization, major_version: 2)
      expect(response).to have_http_status(:success)
      positions = controller.instance_variable_get(:@positions)
      expect(positions).to include(position_v2)
      expect(positions).not_to include(position_v1, position_v1_2, position_v0)
    end

    it 'filters by major version 0' do
      get organization_positions_path(organization, major_version: 0)
      expect(response).to have_http_status(:success)
      positions = controller.instance_variable_get(:@positions)
      expect(positions).to include(position_v0)
      expect(positions).not_to include(position_v1, position_v1_2, position_v2)
    end

    it 'shows all positions when major_version is empty' do
      get organization_positions_path(organization)
      expect(response).to have_http_status(:success)
      positions = controller.instance_variable_get(:@positions)
      expect(positions).to include(position_v1, position_v1_2, position_v2, position_v0)
    end

    it 'includes a link icon next to departments that links to the department show page' do
      department = create(:department, company: organization, name: 'Engineering')
      title_in_dept = create(:title, company: organization, department: department,
        position_major_level: title.position_major_level, external_title: 'Engineer')
      create(:position, title: title_in_dept, position_level: position_level_1, semantic_version: '1.0.0')

      get organization_positions_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(organization_department_path(organization, department))
      expect(response.body).to include('bi-link-45deg')
    end

    it 'shows major level with info icon and tooltip for position_major_level description' do
      pml = title.position_major_level
      pml.update!(description: 'Individual contributor levels')

      get organization_positions_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(pml.major_level.to_s)
      expect(response.body).to include('bi-info-circle')
      expect(response.body).to include('data-bs-toggle="tooltip"')
      expect(response.body).to include('Individual contributor levels')
    end

    it 'includes archive button that shows "archive coming soon" on click' do
      get organization_positions_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('bi-archive')
      expect(response.body).to include('archive coming soon')
      expect(response.body).to include('onclick')
    end
  end

  describe 'GET /organizations/:organization_id/positions/:id/job_description' do
    let(:position) { create(:position, title: title, position_level: position_level) }

    it 'renders job description successfully' do
      get job_description_organization_position_path(organization, position)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(position.display_name)
    end

    it 'shows Additional Abilities required section when position has direct milestone requirements' do
      ability = create(:ability, company: organization, created_by: person, updated_by: person, name: 'Collaboration')
      create(:position_ability, position: position, ability: ability, milestone_level: 2)

      get job_description_organization_position_path(organization, position)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Additional Abilities required')
      expect(response.body).to include('Collaboration')
      expect(response.body).to include('needing Abilities such as')
    end

    it 'does not show Additional Abilities required section when position has no direct milestone requirements' do
      get job_description_organization_position_path(organization, position)

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('Additional Abilities required')
    end
  end
end

