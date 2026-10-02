# frozen_string_literal: true

require "rails_helper"

RSpec.describe Seats::ShowPageData do
  let(:organization) { create(:organization, :company) }
  let(:primary_title) { create(:title, company: organization, external_title: "Engineer") }
  let(:other_title) { create(:title, company: organization, external_title: "Staff Engineer") }
  let(:manager_seat) do
    create(:seat, title: primary_title, seat_needed_by: Date.current + 1.month, state: :open)
  end
  let(:seat) do
    create(
      :seat,
      title: primary_title,
      reports_to_seat: manager_seat,
      seat_needed_by: Date.current + 2.months,
      state: :open
    )
  end
  let(:peer_seat) do
    create(:seat, title: primary_title, seat_needed_by: Date.current + 3.months, state: :draft)
  end
  let(:other_title_seat) do
    create(:seat, title: other_title, seat_needed_by: Date.current + 4.months, state: :open)
  end

  before do
    seat.update!(title_ids: [primary_title.id, other_title.id])
    peer_seat
    other_title_seat
  end

  subject(:data) { described_class.new(seat: seat.reload, organization: organization) }

  it "lists other seats with the same primary title" do
    expect(data.primary_title_peers.title).to eq(primary_title)
    expect(data.primary_title_peers.seats.map { |row| row.seat.id }).to include(peer_seat.id, manager_seat.id)
    expect(data.primary_title_peers.seats.map { |row| row.seat.id }).not_to include(seat.id)
  end

  it "lists seats sharing an additional title that are not in the primary group" do
    groups = data.other_title_peer_groups
    expect(groups.map { |g| g.title.id }).to eq([other_title.id])
    expect(groups.first.seats.map { |row| row.seat.id }).to eq([other_title_seat.id])
  end

  it "builds org chart payloads that include ancestors and highlight the current seat" do
    expect(data.highcharts_organization_data[:nodes].map { |n| n[:id] }).to include(
      "seat_#{seat.id}",
      "seat_#{manager_seat.id}"
    )
    current_node = data.highcharts_organization_data[:nodes].find { |n| n[:id] == "seat_#{seat.id}" }
    expect(current_node[:color]).to eq("#0d6efd")

    tree_nodes = data.highcharts_treegraph_data[:nodes]
    expect(tree_nodes.map { |n| n[:id] }).to include("seat_#{seat.id}", "seat_#{manager_seat.id}")
    child = tree_nodes.find { |n| n[:id] == "seat_#{seat.id}" }
    expect(child[:parent]).to eq("seat_#{manager_seat.id}")
    expect(child[:color]).to eq("#0d6efd")
    root = tree_nodes.find { |n| n[:id] == "seat_#{manager_seat.id}" }
    expect(root[:parent]).to be_nil

    current_cyto = data.cytoscape_elements.find { |el| el.dig(:data, :id) == "seat_#{seat.id}" }
    expect(current_cyto.dig(:data, :isCurrent)).to be(true)
    expect(data.hierarchy_roots).to be_present
  end
end
