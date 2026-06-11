require 'rails_helper'

RSpec.describe Assignments::BulkCloseAssignmentTenuresService do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Sales Forecasting') }
  let(:creator) { create(:person, first_name: 'Alex', last_name: 'Manager') }
  let(:creator_teammate) { create(:teammate, person: creator, organization: organization) }
  let(:employee_teammate) { create(:teammate, organization: organization) }
  let!(:active_tenure) do
    create(:assignment_tenure,
           assignment: assignment,
           teammate: employee_teammate,
           started_at: 1.month.ago,
           anticipated_energy_percentage: 50,
           ended_at: nil)
  end
  let!(:zero_energy_active_tenure) do
    other_teammate = create(:teammate, organization: organization)
    create(:assignment_tenure,
           assignment: assignment,
           teammate: other_teammate,
           started_at: 2.weeks.ago,
           anticipated_energy_percentage: 0,
           ended_at: nil)
  end

  it 'closes all active tenures and creates a MAAP snapshot per teammate' do
    expect do
      result = described_class.call(
        assignment: assignment,
        creator_teammate: creator_teammate,
        request_info: { ip_address: '127.0.0.1' }
      )
      expect(result.ok?).to be true
      expect(result.value[:closed_count]).to eq(2)
    end.to change(MaapSnapshot, :count).by(2)

    expect(active_tenure.reload.ended_at.to_date).to eq(Date.current)
    expect(active_tenure.anticipated_energy_percentage).to eq(0)
    expect(zero_energy_active_tenure.reload.ended_at.to_date).to eq(Date.current)

    snapshot = MaapSnapshot.find_by(employee_company_teammate: employee_teammate)
    expect(snapshot.change_type).to eq('assignment_management')
    expect(snapshot.reason).to eq(
      "#{creator.casual_name} executed a bulk action to close out all active tenures of the \"Sales Forecasting\" assignment"
    )
    expect(snapshot.effective_date).to eq(Date.current)
  end

  it 'returns an error when there are no active tenures' do
    assignment.assignment_tenures.update_all(ended_at: 1.day.ago)

    result = described_class.call(
      assignment: assignment,
      creator_teammate: creator_teammate
    )

    expect(result.ok?).to be false
    expect(result.error).to include('No active assignment tenures')
  end
end
