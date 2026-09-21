# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assignments::RelianceManager do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Core") }
  let(:upstream) { create(:assignment, company: organization, title: "Upstream") }
  let(:downstream) { create(:assignment, company: organization, title: "Downstream") }
  let(:unrelated) { create(:assignment, company: organization, title: "Unrelated") }

  it "creates upstream and downstream relationships from association params" do
    result = described_class.call(
      assignment: assignment,
      associations: {
        upstream.id => { direction: "upstream" },
        downstream.id => { direction: "downstream" },
        unrelated.id => { direction: "none" }
      }
    )

    expect(result.ok?).to be true
    expect(assignment.reload.supplier_assignments).to contain_exactly(upstream)
    expect(assignment.consumer_assignments).to contain_exactly(downstream)
  end

  it "switches direction by replacing the opposite relationship" do
    create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

    result = described_class.call(
      assignment: assignment,
      associations: {
        downstream.id => { direction: "upstream" }
      }
    )

    expect(result.ok?).to be true
    assignment.reload
    expect(assignment.consumer_assignments).to be_empty
    expect(assignment.supplier_assignments).to contain_exactly(downstream)
  end

  it "clears relationships marked none and omits missing associations" do
    create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)
    create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)

    result = described_class.call(
      assignment: assignment,
      associations: {
        downstream.id => { direction: "none" },
        upstream.id => { direction: "upstream" }
      }
    )

    expect(result.ok?).to be true
    assignment.reload
    expect(assignment.consumer_assignments).to be_empty
    expect(assignment.supplier_assignments).to contain_exactly(upstream)
  end

  it "ignores the subject assignment and unknown ids" do
    result = described_class.call(
      assignment: assignment,
      associations: {
        assignment.id => { direction: "downstream" },
        0 => { direction: "upstream" }
      }
    )

    expect(result.ok?).to be true
    expect(assignment.reload.consumer_assignments).to be_empty
    expect(assignment.supplier_assignments).to be_empty
  end
end
