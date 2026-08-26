# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::EmployeeEntries do
  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: company) }

  it "builds sorted goals entries with status detail" do
    healthy = create(:teammate, :assigned_employee, organization: company, person: create(:person, first_name: "Zoey"))
    concerning = create(:teammate, :assigned_employee, organization: company, person: create(:person, first_name: "Alex"))

    entries = described_class.from_goals_rows(
      [
        {
          teammate: healthy,
          person: healthy.person,
          status: :healthy,
          eh_status: EngagementHealth::HEALTHY,
          status_lines: {
            EngagementHealth::HEALTHY => { active: 2, completed: 0, draft: 0 },
            EngagementHealth::WARNING => { active: 0, completed: 0, draft: 0 },
            EngagementHealth::NEEDS_ATTENTION => { active: 0, completed: 0, draft: 0 }
          }
        },
        {
          teammate: concerning,
          person: concerning.person,
          status: :concerning,
          eh_status: EngagementHealth::NEEDS_ATTENTION,
          status_lines: {
            EngagementHealth::HEALTHY => { active: 0, completed: 0, draft: 0 },
            EngagementHealth::WARNING => { active: 0, completed: 0, draft: 0 },
            EngagementHealth::NEEDS_ATTENTION => { active: 1, completed: 0, draft: 0 }
          }
        }
      ]
    )

    expect(entries.first[:name]).to start_with("Alex")
    expect(entries.last[:name]).to start_with("Zoey")
    expect(entries.first[:status]).to eq(EngagementHealth::NEEDS_ATTENTION)
    expect(entries.first[:detail]).to include("Needs Attention")
    expect(entries.first[:action_url]).to include("/my_growth/goals")
    expect(entries.first[:action_button_label]).to match(/\AGo to Alex.*'s Goals Page\z/)
  end

  it "builds protect flow entries from person cards" do
    entries = described_class.from_protect_flow_people(
      [
        {
          teammate: teammate,
          name: teammate.person.casual_name,
          worst_status: EngagementHealth::WARNING,
          unhealthy_count: 1,
          hero: { title: "Clarity Check-ins", why: "Stale clarity kills flow." }
        }
      ]
    )

    expect(entries.size).to eq(1)
    expect(entries.first[:status]).to eq(EngagementHealth::WARNING)
    expect(entries.first[:detail]).to include("Clarity Check-ins")
    expect(entries.first[:detail]).to include("Stale clarity")
    expect(entries.first[:action_url]).to include("/one_on_one_link")
    expect(entries.first[:action_button_label]).to include("One Thing Page")
  end
end
