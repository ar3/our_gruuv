# frozen_string_literal: true

require "rails_helper"

RSpec.describe ObjectMaintainer, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }

  it "links a teammate as maintainer of a maintainable object" do
    membership = described_class.create!(
      maintainable: assignment,
      company_teammate: teammate
    )

    expect(membership).to be_persisted
    expect(assignment.maintainers).to include(teammate)
    expect(assignment.maintained_by?(teammate)).to eq(true)
  end

  it "rejects teammates from another organization" do
    other = create(:teammate, :assigned_employee, organization: create(:organization))

    membership = described_class.new(maintainable: assignment, company_teammate: other)
    expect(membership).not_to be_valid
    expect(membership.errors[:company_teammate]).to be_present
  end

  it "enforces uniqueness per object and teammate" do
    described_class.create!(maintainable: assignment, company_teammate: teammate)
    duplicate = described_class.new(maintainable: assignment, company_teammate: teammate)
    expect(duplicate).not_to be_valid
  end

  it "works for positions and abilities" do
    ability = create(:ability, company: organization)
    described_class.create!(maintainable: ability, company_teammate: teammate)
    expect(ability.maintainers).to include(teammate)

    major = create(:position_major_level)
    level = create(:position_level, position_major_level: major, level: "1.1")
    title = create(:title, company: organization, position_major_level: major)
    position = create(:position, title: title, position_level: level)
    described_class.create!(maintainable: position, company_teammate: teammate)
    expect(position.maintainers).to include(teammate)

    expect(described_class.maintained_assignment_ids_for(teammate)).to eq([])
  end
end
