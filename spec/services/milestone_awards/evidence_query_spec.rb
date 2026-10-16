# frozen_string_literal: true

require "rails_helper"

RSpec.describe MilestoneAwards::EvidenceQuery do
  let(:organization) { create(:organization) }
  let(:manager) { create(:teammate, :assigned_employee, :employment_manager, organization: organization) }
  let(:peer) { create(:teammate, :assigned_employee, organization: organization) }
  let(:recipient) { create(:teammate, :assigned_employee, organization: organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  before do
    create(:employment_tenure, teammate: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: recipient, company: organization, started_at: 1.year.ago, ended_at: nil,
                               manager_teammate: manager)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
    create(:assignment_tenure, teammate: recipient, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
  end

  it "lists active requiring assignments with check-in access for managers" do
    create(
      :assignment_check_in,
      teammate: recipient,
      assignment: assignment,
      check_in_started_on: 2.weeks.ago,
      official_check_in_completed_at: 1.week.ago,
      official_rating: "meeting",
      manager_completed_by_teammate: manager,
      finalized_by_teammate: manager
    )

    result = described_class.call(
      organization: organization,
      viewer_person: manager.person,
      viewing_teammate: manager,
      teammate: recipient,
      ability: ability
    )

    expect(result[:can_view_assignment_check_ins]).to eq(true)
    expect(result[:assignment_rows].map { |r| r.assignment.id }).to eq([assignment.id])
    expect(result[:assignment_rows].first.recent_check_ins.first.rating_label)
      .to eq("🔵 Meeting Expectations of this Assignment")
    expect(result[:observations_index_path]).to include("rateable_type=Ability")
    expect(result[:observations_index_path]).to include("rateable_id=#{ability.id}")
  end

  it "denies assignment check-ins to peers without manage employment" do
    result = described_class.call(
      organization: organization,
      viewer_person: peer.person,
      viewing_teammate: peer,
      teammate: recipient,
      ability: ability
    )

    expect(result[:can_view_assignment_check_ins]).to eq(false)
    expect(result[:assignment_rows]).to eq([])
    expect(result[:assignment_check_ins_denied_message]).to include("management chain")
  end
end
