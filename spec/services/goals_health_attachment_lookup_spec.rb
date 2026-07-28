# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoalsHealthAttachmentLookup do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago, last_terminated_at: nil) }

  it "batches association and child facts and builds a display entry for active goals" do
    assignment = create(:assignment, company: organization)
    ability = create(:ability, company: organization)
    parent = create(:goal, owner: teammate, company: organization, started_at: 1.week.ago, title: "Parent")
    child = create(:goal, owner: teammate, company: organization, started_at: 1.week.ago, title: "Child")
    create(:goal_link, parent: parent, child: child)
    create(:goal_association, goal: child, associable: assignment)
    create(:goal_association, goal: child, associable: ability)

    facts = described_class.load_for_goals([parent, child])
    entry = described_class.entry_for_active_goals([parent, child], facts)

    expect(entry.active_child_count).to eq(1)
    expect(entry.active_with_attachments_count).to eq(1)
    expect(entry.type_groups.map(&:associable_type)).to contain_exactly("Assignment", "Ability")
    assignment_group = entry.type_groups.find { |g| g.associable_type == "Assignment" }
    expect(assignment_group.sole.name).to eq(assignment.display_name.presence || assignment.name)
  end

  it "includes prompt attachments with the same sole-vs-count rules" do
    prompt = create(:prompt, company_teammate: teammate)
    goal = create(:goal, owner: teammate, company: organization, started_at: 1.week.ago)
    create(:prompt_goal, prompt: prompt, goal: goal)

    facts = described_class.load_for_goals([goal])
    entry = described_class.entry_for_active_goals([goal], facts)

    expect(entry.active_with_attachments_count).to eq(1)
    prompt_group = entry.type_groups.find { |g| g.associable_type == "Prompt" }
    expect(prompt_group.sole.name).to eq(prompt.prompt_template.title)
  end
end
