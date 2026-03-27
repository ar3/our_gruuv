# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIns::AllFreshBannerService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, first_name: 'Alex') }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:manager_teammate) { create(:teammate, organization: organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, company: organization, external_title: 'Engineer', position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:assignment) { create(:assignment, company: organization, title: 'Core work') }
  let!(:position_assignment) { create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required') }
  let!(:employment_tenure) do
    create(:employment_tenure, teammate: teammate, position: position, company: organization, started_at: 1.year.ago, ended_at: nil)
  end
  let!(:assignment_tenure) do
    create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 6.months.ago, ended_at: nil)
  end
  let(:aspiration) { create(:aspiration, company: organization, name: 'Growth') }
  let(:open_position) do
    PositionCheckIn.find_or_create_open_for(teammate).tap do |ci|
      ci.update!(employee_completed_at: nil, manager_completed_at: nil, manager_completed_by_teammate: nil)
    end
  end
  let(:open_aspiration) do
    AspirationCheckIn.find_or_create_open_for(teammate, aspiration).tap do |ci|
      ci.update!(employee_completed_at: nil, manager_completed_at: nil, manager_completed_by_teammate: nil)
    end
  end
  let(:open_assignment) do
    AssignmentCheckIn.find_or_create_open_for(teammate, assignment).tap do |ci|
      ci.update!(employee_completed_at: nil, manager_completed_at: nil, manager_completed_by_teammate: nil)
    end
  end

  def call(view_mode: :manager)
    described_class.call(
      teammate: teammate,
      organization: organization,
      view_mode: view_mode,
      position_check_in: open_position,
      aspiration_check_ins: [open_aspiration],
      assignment_check_ins: [open_assignment]
    )
  end

  before do
    # Closed history so "latest finalized" exists; page still has new open rows.
    create(:position_check_in, :closed,
           teammate: teammate,
           employment_tenure: employment_tenure,
           official_check_in_completed_at: 10.days.ago,
           finalized_by_teammate: manager_teammate)
    create(:aspiration_check_in, :finalized,
           teammate: teammate,
           aspiration: aspiration,
           official_check_in_completed_at: 20.days.ago,
           finalized_by_teammate: manager_teammate)
    create(:assignment_check_in, :finalized,
           teammate: teammate,
           assignment: assignment,
           official_check_in_completed_at: 5.days.ago,
           finalized_by_teammate: manager_teammate)
  end

  it 'shows banner and follow-up when every item was finalized within 60 days' do
    result = call(view_mode: :manager)
    expect(result.show_banner).to be true
    expect(result.show_clarity_follow_up).to be true
    expect(result.check_back_in_days).to eq(40) # 60 - 20 days since earliest (aspiration)
    expect(result.organization_display_name).to eq(organization.name)
  end

  it 'hides follow-up when freshness is only from viewer-completed open rows' do
    open_position.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_teammate)
    open_aspiration.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_teammate)
    open_assignment.update!(manager_completed_at: Time.current, manager_completed_by_teammate: manager_teammate)

    AspirationCheckIn.where(teammate_id: teammate.id, aspiration: aspiration).closed.delete_all
    PositionCheckIn.where(teammate_id: teammate.id).closed.delete_all
    AssignmentCheckIn.where(teammate_id: teammate.id, assignment: assignment).closed.delete_all

    result = call(view_mode: :manager)
    expect(result.show_banner).to be true
    expect(result.show_clarity_follow_up).to be false
    expect(result.check_back_in_days).to be_nil
  end

  it 'does not show banner when the viewer has not completed their side and last finalization is older than 60 days' do
    past = 70.days.ago
    PositionCheckIn.where(teammate_id: teammate.id).closed.update_all(official_check_in_completed_at: past)
    AspirationCheckIn.where(teammate_id: teammate.id, aspiration: aspiration).closed.update_all(official_check_in_completed_at: past)
    AssignmentCheckIn.where(teammate_id: teammate.id, assignment: assignment).closed.update_all(official_check_in_completed_at: past)

    result = call(view_mode: :employee)
    expect(result.show_banner).to be false
  end

  it 'shows banner for employee when employee side is complete on open rows' do
    open_position.update!(employee_completed_at: Time.current)
    open_aspiration.update!(employee_completed_at: Time.current)
    open_assignment.update!(employee_completed_at: Time.current)

    AspirationCheckIn.where(teammate_id: teammate.id, aspiration: aspiration).closed.delete_all
    PositionCheckIn.where(teammate_id: teammate.id).closed.delete_all
    AssignmentCheckIn.where(teammate_id: teammate.id, assignment: assignment).closed.delete_all

    result = call(view_mode: :employee)
    expect(result.show_banner).to be true
    expect(result.show_clarity_follow_up).to be false
  end

  it 'returns check back today when the earliest finalized is exactly 60 days ago' do
    AspirationCheckIn.where(teammate_id: teammate.id, aspiration: aspiration).closed.update_all(official_check_in_completed_at: 60.days.ago)
    PositionCheckIn.where(teammate_id: teammate.id).closed.update_all(official_check_in_completed_at: 30.days.ago)
    AssignmentCheckIn.where(teammate_id: teammate.id, assignment: assignment).closed.update_all(official_check_in_completed_at: 45.days.ago)

    result = call(view_mode: :manager)
    expect(result.show_clarity_follow_up).to be true
    expect(result.check_back_in_days).to eq(0)
  end
end
