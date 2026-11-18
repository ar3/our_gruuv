# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::ExpandProgressiveOutcome, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "creates a parent and commit/stretch/transform children" do
    result = described_class.call(
      organization: organization,
      current_person: person,
      current_teammate: teammate,
      attrs: {
        title: "Move retention from 50% to [60|70|80]%",
        owner_id: "CompanyTeammate_#{teammate.id}"
      }
    )

    expect(result.ok?).to be(true), -> { result.error.inspect }
    expect(result.parent.goal_type).to eq("inspirational_objective")
    expect(result.children.size).to eq(3)
    expect(result.children.map(&:progressive_current_aim)).to match_array(%w[commit stretch transform])
    expect(result.children.map { |c| c.linking_goals }).to all(include(result.parent))
  end
end
