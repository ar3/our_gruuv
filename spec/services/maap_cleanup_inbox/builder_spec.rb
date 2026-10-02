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

  def seat_section(sections)
    sections.find { |section| section.key == :seat_position_alignment }
  end

  def proposals_section(sections)
    sections.find { |section| section.key == :submitted_maap_proposals }
  end

  it "returns submitted proposals and seat ↔ position sections collapsed by default" do
    create_mismatched_tenure!

    sections = described_class.call(organization: organization)
    subtype = seat_section(sections).subtypes.first

    expect(sections.map(&:key)).to eq(%i[submitted_maap_proposals seat_position_alignment])
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
    subtype = seat_section(sections).subtypes.first
    item = subtype.items.first

    expect(subtype.expanded).to be(true)
    expect(subtype.count).to eq(1)
    expect(item.person_name).to eq(person.display_name)
    expect(item.title).to eq("#{tenure.seat.display_name} ↔ #{tenure.position.title.display_name}")
    expect(item.title).not_to include(tenure.position.position_level.level)
    expect(item.actions.map(&:label)).to eq([
      "Change #{person.casual_name}'s Seat",
      "Add Positions to #{tenure.seat.display_name}"
    ])
    expect(item.actions.map(&:url)).to eq([
      Rails.application.routes.url_helpers.edit_organization_company_teammate_employment_tenure_path(
        organization,
        teammate,
        tenure
      ),
      Rails.application.routes.url_helpers.manage_titles_organization_seat_path(organization, tenure.seat)
    ])
  end

  it "includes submitted create and edit proposals when expanded" do
    assignment = create(:assignment, company: organization, title: "Live Assignment")
    create(
      :maap_proposal,
      :submitted,
      assignment: assignment,
      proposer: teammate,
      proposed_payload: {
        "schema_version" => 2,
        "title" => "Edited Title",
        "tagline" => "tag",
        "outcomes" => [],
        "ability_milestones" => [],
        "consumer_assignment_ids" => [],
        "supplier_assignment_ids" => []
      }
    )
    create(
      :maap_proposal,
      :create_kind,
      :submitted,
      organization: organization,
      proposer: teammate,
      proposed_payload: {
        "schema_version" => 2,
        "title" => "Brand New",
        "tagline" => "tag",
        "outcomes" => [],
        "ability_milestones" => [],
        "consumer_assignment_ids" => [],
        "supplier_assignment_ids" => []
      }
    )
    create(
      :maap_proposal,
      :ability_create,
      :submitted,
      organization: organization,
      proposer: teammate,
      proposed_payload: {
        "schema_version" => 1,
        "name" => "New Ability Create",
        "description" => "desc",
        "milestone_1_description" => "m1"
      }
    )

    sections = described_class.call(
      organization: organization,
      expanded_subtype_keys: [:submitted_maap_proposals]
    )
    subtype = proposals_section(sections).subtypes.first

    expect(subtype.count).to eq(3)
    expect(subtype.items.map(&:title)).to include(
      "Edit: Edited Title",
      "Create: Brand New",
      "Create: New Ability Create"
    )
    expect(subtype.items.flat_map { |item| item.actions.map(&:label) }).to all(eq("Review proposal"))
    ability_create_item = subtype.items.find { |item| item.title == "Create: New Ability Create" }
    expect(ability_create_item.actions.first.url).to include("/maap_ability_creates/")
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
    expect(seat_section(sections).subtypes.first.count).to eq(0)
  end
end
