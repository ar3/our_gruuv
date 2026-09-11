# frozen_string_literal: true

require "rails_helper"

RSpec.describe Positions::SuggestedNextForGrowBy do
  let(:organization) { create(:organization) }
  let(:major) { create(:position_major_level, major_level: 2, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:dest_major) { create(:position_major_level, major_level: 3, set_name: "Base-#{SecureRandom.hex(4)}") }
  let(:title) { create(:title, company: organization, position_major_level: major, external_title: "Engineer") }
  let(:level_21) { create(:position_level, position_major_level: major, level: "2.1") }
  let(:level_22) { create(:position_level, position_major_level: major, level: "2.2") }
  let(:level_23) { create(:position_level, position_major_level: major, level: "2.3") }
  let!(:pos_21) { create(:position, title: title, position_level: level_21) }
  let!(:pos_22) { create(:position, title: title, position_level: level_22) }
  let!(:pos_23) { create(:position, title: title, position_level: level_23) }

  it "returns an empty note when there is no current position" do
    result = described_class.call(current_position: nil)

    expect(result.positions).to be_empty
    expect(result.empty_note).to include("No current position")
  end

  it "suggests all higher levels on the same title" do
    result = described_class.call(current_position: pos_21)

    expect(result.same_title_positions).to eq([pos_22, pos_23])
    expect(result.path_positions).to be_empty
    expect(result.empty_note).to be_nil
  end

  it "suggests all positions on outbound path destination titles" do
    dest_title = create(:title, company: organization, position_major_level: dest_major, external_title: "Staff Engineer")
    dest_level = create(:position_level, position_major_level: dest_major, level: "3.1")
    dest_level_2 = create(:position_level, position_major_level: dest_major, level: "3.2")
    dest_pos_1 = create(:position, title: dest_title, position_level: dest_level)
    dest_pos_2 = create(:position, title: dest_title, position_level: dest_level_2)
    create(:title_path, from_title: title, to_title: dest_title, path_type: "natural_progression")

    result = described_class.call(current_position: pos_23)

    expect(result.same_title_positions).to be_empty
    expect(result.path_positions).to include(dest_pos_1, dest_pos_2)
    expect(result.positions).not_to include(pos_21, pos_22, pos_23)
  end

  it "combines higher same-title levels with outbound path positions" do
    dest_title = create(:title, company: organization, position_major_level: dest_major, external_title: "Staff Engineer")
    dest_level = create(:position_level, position_major_level: dest_major, level: "3.1")
    dest_pos = create(:position, title: dest_title, position_level: dest_level)
    create(:title_path, from_title: title, to_title: dest_title, path_type: "parallel_progression")

    result = described_class.call(current_position: pos_21)

    expect(result.same_title_positions).to eq([pos_22, pos_23])
    expect(result.path_positions).to eq([dest_pos])
    expect(result.positions).to eq([pos_22, pos_23, dest_pos])
  end

  it "returns an end-cap note when there is nowhere higher and no outbound" do
    title.update!(end_cap: true)
    result = described_class.call(current_position: pos_23)

    expect(result.positions).to be_empty
    expect(result.empty_note).to include("end-cap")
  end
end
