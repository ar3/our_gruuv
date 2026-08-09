# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organization assignment maintainers", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) do
    create(:teammate, :assigned_employee, :maap_manager, person: person, organization: organization)
  end
  let(:assignment) { create(:assignment, company: organization) }
  let!(:other) { create(:teammate, :assigned_employee, organization: organization) }

  before { sign_in_as_teammate_for_request(person, organization) }

  it "allows MAAP admins to manage maintainers" do
    get organization_assignment_maintainers_path(organization, assignment)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Manage Maintainers")
    expect(response.body).to include(other.person.display_name)

    patch organization_assignment_maintainers_path(organization, assignment),
          params: { maintainer_teammate_ids: [ other.id ] }

    expect(response).to redirect_to(organization_assignment_path(organization, assignment))
    expect(assignment.reload.maintainers).to contain_exactly(other)

    get organization_assignment_path(organization, assignment)
    expect(response.body).to include("Maintainers")
    expect(response.body).to include(other.person.display_name)
  end

  context "as an existing maintainer without MAAP" do
    let!(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

    before do
      create(:object_maintainer, maintainable: assignment, company_teammate: teammate)
    end

    it "can open the manage page and cannot remove self" do
      get organization_assignment_maintainers_path(organization, assignment)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("cannot remove yourself")

      patch organization_assignment_maintainers_path(organization, assignment),
            params: { maintainer_teammate_ids: [ other.id ] }

      expect(assignment.reload.maintainers).to contain_exactly(teammate, other)
    end
  end
end
