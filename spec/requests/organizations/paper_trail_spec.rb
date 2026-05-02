require 'rails_helper'

RSpec.describe 'Organizations::PaperTrail', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:person_teammate) { create(:teammate, :unassigned_employee, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/paper_trail' do
    it 'renders change history when item_type and item_id refer to an assignment in this org' do
      get organization_paper_trail_path(
        organization,
        item_type: 'Assignment',
        item_id: assignment.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Change history')
      expect(response.body).to include('Assignment')
      expect(response.body).to include(assignment.title)
      expect(response.body).to include('Show details')
      expect(response.body).not_to include('data-bs-toggle="popover"')
    end

    it 'returns not found for unknown item_type' do
      get organization_paper_trail_path(
        organization,
        item_type: 'UnknownModel',
        item_id: assignment.id
      )
      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found when the record belongs to another organization' do
      other_org = create(:organization)
      other_assignment = create(:assignment, company: other_org)

      get organization_paper_trail_path(
        organization,
        item_type: 'Assignment',
        item_id: other_assignment.id
      )
      expect(response).to have_http_status(:not_found)
    end
  end
end
