require 'rails_helper'

RSpec.describe 'Manager Filter Bug', type: :system, js: true do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:direct_report) { create(:person, first_name: 'Direct', last_name: 'Report') }
  
  let!(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let!(:direct_report_teammate) { create(:teammate, person: direct_report, organization: organization) }

  before do
    # Create employment tenure with manager relationship
    create(:employment_tenure, teammate: direct_report_teammate, company: organization, manager: manager, ended_at: nil)
  end

  it 'shows only direct reports when manager_filter=direct_reports' do
    sign_in_and_visit(manager, organization, organization_employees_path(organization, manager_filter: 'direct_reports'))
    
    # The bug is that this shows ALL teammates, not just direct reports
    # If the spec fails with the current code, it proves the bug exists
    expect(page).to have_content('Direct Report')
    expect(page).not_to have_content('manager') # This should fail if the bug exists
  end
end
