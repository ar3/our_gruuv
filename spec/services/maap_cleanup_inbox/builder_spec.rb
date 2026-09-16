# frozen_string_literal: true

require "rails_helper"

RSpec.describe MaapCleanupInbox::Builder do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, :assigned_employee, person: person, organization: organization) }

  def create_mismatched_tenure!
    other_title = create(:title, company: organization)
    seat = create(:seat, title: other_title, seat_needed_by: Date.current + 2.months)
    # Factory builds a position with a different title than the seat → mismatch.
    create(
      :employment_tenure,
      company: organization,
      company_teammate: teammate,
      seat: seat,
      ended_at: nil
    )
  end

  it "returns the seat ↔ position section collapsed by default" do
    create_mismatched_tenure!

    sections = described_class.call(organization: organization)
    section = sections.first
    subtype = section.subtypes.first

    expect(sections.map(&:key)).to eq(%i[seat_position_alignment])
    expect(subtype.key).to eq(:mismatched_seat_position)
    expect(subtype.count).to eq(1)
    expect(subtype.expanded).to be(false)
    expect(subtype.items).to be_empty
  end

  it "includes mismatched tenure rows when the subtype is expanded" do
    tenure = create_mismatched_tenure!

    sections = described_class.call(
      organization: organization,
      expanded_subtype_keys: [:mismatched_seat_position]
    )
    subtype = sections.first.subtypes.first
    item = subtype.items.first

    expect(subtype.expanded).to be(true)
    expect(subtype.count).to eq(1)
    expect(item.person_name).to eq(person.display_name)
    expect(item.title).to eq("#{tenure.seat.display_name} ↔ #{tenure.position.title.display_name}")
    expect(item.title).not_to include(tenure.position.position_level.level)
    expect(item.tenure_url).to include("/employment_tenures/#{tenure.id}")
    expect(item.seat_url).to include("/seats/#{tenure.seat_id}")
  end

  it "ignores ended tenures and matching seat/position pairs" do
    matching_title = create(:title, company: organization)
    matching_seat = create(:seat, title: matching_title, seat_needed_by: Date.current + 3.months)
    create(
      :employment_tenure,
      :with_seat,
      company: organization,
      company_teammate: teammate,
      seat: matching_seat,
      ended_at: nil
    )

    other_teammate = create(:teammate, :assigned_employee, organization: organization)
    other_title = create(:title, company: organization)
    mismatched_seat = create(:seat, title: other_title, seat_needed_by: Date.current + 4.months)
    create(
      :employment_tenure,
      company: organization,
      company_teammate: other_teammate,
      seat: mismatched_seat,
      ended_at: 1.day.ago
    )

    sections = described_class.call(organization: organization)
    expect(sections.first.subtypes.first.count).to eq(0)
  end
end
