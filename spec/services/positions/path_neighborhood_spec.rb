# frozen_string_literal: true

require "rails_helper"

RSpec.describe Positions::PathNeighborhood do
  let(:organization) { create(:organization) }
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:dest_major) { create(:position_major_level, major_level: 3, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:inbound_major) { create(:position_major_level, major_level: 1, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let(:level_21) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:level_22) { create(:position_level, position_major_level: major, level: "2.2") }
  let(:level_23) { create(:position_level, position_major_level: major, level: "2.3") }
  let!(:pos_21) { create(:position, title: title, position_level: level_21) }
  let!(:pos_22) { create(:position, title: title, position_level: level_22) }
  let!(:pos_23) { create(:position, title: title, position_level: level_23) }

  it "for L1, before is latest on inbound titles and after is same-title L2" do
    inbound_title = create(:title, company: organization, position_major_level: inbound_major, external_title: "Associate Engineer")
    inbound_l1 = create(:position_level, position_major_level: inbound_major, level: "1.1")
    inbound_l3 = create(:position_level, position_major_level: inbound_major, level: "1.3")
    create(:position, title: inbound_title, position_level: inbound_l1)
    inbound_exit = create(:position, title: inbound_title, position_level: inbound_l3)
    create(:title_path, from_title: inbound_title, to_title: title, path_type: "natural_progression")

    result = described_class.call(position: pos_21)

    expect(result.positions_before.map(&:position)).to eq([inbound_exit])
    expect(result.positions_before.first.path_type_label).to eq("Natural progression")
    expect(result.positions_after.map(&:position)).to eq([pos_22])
    expect(result.after_state).to eq(:within_title)
  end

  it "for L2, before is L1 and after is L3 on the same title" do
    result = described_class.call(position: pos_22)

    expect(result.positions_before.map(&:position)).to eq([pos_21])
    expect(result.positions_after.map(&:position)).to eq([pos_23])
    expect(result.after_state).to eq(:within_title)
  end

  it "for L3, after is the earliest position on each outbound destination title" do
    dest_title = create(:title, company: organization, position_major_level: dest_major, external_title: "Staff Engineer")
    dest_l1 = create(:position_level, position_major_level: dest_major, level: "3.1")
    dest_l2 = create(:position_level, position_major_level: dest_major, level: "3.2")
    dest_pos_1 = create(:position, title: dest_title, position_level: dest_l1)
    create(:position, title: dest_title, position_level: dest_l2)
    create(:title_path, from_title: title, to_title: dest_title, path_type: "parallel_progression")

    result = described_class.call(position: pos_23)

    expect(result.positions_before.map(&:position)).to eq([pos_22])
    expect(result.positions_after.map(&:position)).to eq([dest_pos_1])
    expect(result.positions_after.first.path_type_label).to eq("Parallel progression")
    expect(result.after_state).to eq(:outbound_paths)
  end

  it "for L3 end-cap, after is empty with end_cap state" do
    title.update!(end_cap: true)

    result = described_class.call(position: pos_23)

    expect(result.positions_after).to be_empty
    expect(result.after_state).to eq(:end_cap)
    expect(result).to be_end_cap
  end

  it "for L3 with no outbound and not end-cap, after is undefined" do
    result = described_class.call(position: pos_23)

    expect(result.positions_after).to be_empty
    expect(result.after_state).to eq(:undefined)
    expect(result).to be_undefined_after
  end

  it "for L1 with no L2 defined, marks missing_next_level" do
    pos_22.archive!
    pos_23.archive!

    result = described_class.call(position: pos_21)

    expect(result.positions_after).to be_empty
    expect(result.after_state).to eq(:missing_next_level)
  end
end
