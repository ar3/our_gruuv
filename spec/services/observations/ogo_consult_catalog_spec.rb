# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observations::OgoConsultCatalog do
  let(:organization) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observee) { create(:teammate, organization: organization) }
  let(:observation) do
    create(:observation, observer: observer, company: organization).tap do |obs|
      obs.observees.destroy_all
      obs.observees.create!(teammate: observee)
    end
  end
  let(:assignment) { create(:assignment, company: organization, title: "Launch Owner") }
  let(:ability) { create(:ability, company: organization, name: "Risk Naming") }
  let!(:aspiration) { create(:aspiration, company: organization, department: nil, name: "Candor") }

  before do
    create(:assignment_tenure, teammate: observee, assignment: assignment, anticipated_energy_percentage: 40)
    create(:assignment_ability, assignment: assignment, ability: ability)
  end

  it "includes observee assignments, related abilities, and company values" do
    entries = described_class.call(observation: observation)
    names = entries.map(&:name)

    expect(names).to include("Launch Owner", "Risk Naming", "Candor")
    expect(entries.map(&:rateable_type)).to include("Assignment", "Ability", "Aspiration")
  end

  it "omits assignments the observee does not carry" do
    other = create(:assignment, company: organization, title: "Not Theirs")
    entries = described_class.call(observation: observation)

    expect(entries.map(&:name)).not_to include("Not Theirs")
    expect(other).to be_persisted
  end
end
