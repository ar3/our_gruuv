# frozen_string_literal: true

require "rails_helper"

RSpec.describe Titles::PathManager do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: major_level, external_title: "Engineer") }
  let(:next_title) { create(:title, company: organization, position_major_level: major_level, external_title: "Manager") }
  let(:prior_title) { create(:title, company: organization, position_major_level: major_level, external_title: "Associate") }

  it "creates outbound and inbound paths from association params" do
    result = described_class.call(
      title: title,
      end_cap: false,
      associations: {
        next_title.id => { direction: "outbound", path_type: "switch_to_people_management" },
        prior_title.id => { direction: "inbound", path_type: "natural_progression" }
      }
    )

    expect(result.ok?).to be(true)
    expect(title.reload.outbound_titles).to contain_exactly(next_title)
    expect(title.inbound_titles).to contain_exactly(prior_title)
    expect(title.outbound_title_paths.first.path_type).to eq("switch_to_people_management")
  end

  it "clears outbound paths when marking end-cap" do
    create(:title_path, from_title: title, to_title: next_title, path_type: "natural_progression")

    result = described_class.call(
      title: title,
      end_cap: true,
      associations: {
        next_title.id => { direction: "outbound", path_type: "natural_progression" }
      }
    )

    expect(result.ok?).to be(true)
    expect(title.reload.end_cap?).to be(true)
    expect(title.outbound_title_paths).to be_empty
  end

  it "removes paths set to none" do
    create(:title_path, from_title: title, to_title: next_title, path_type: "natural_progression")

    result = described_class.call(
      title: title,
      end_cap: false,
      associations: {
        next_title.id => { direction: "none", path_type: "natural_progression" }
      }
    )

    expect(result.ok?).to be(true)
    expect(title.reload.outbound_title_paths).to be_empty
  end
end
