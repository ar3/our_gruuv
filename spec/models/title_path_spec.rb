# frozen_string_literal: true

require "rails_helper"

RSpec.describe TitlePath, type: :model do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:from_title) { create(:title, company: organization, position_major_level: major_level, external_title: "Engineer") }
  let(:to_title) { create(:title, company: organization, position_major_level: major_level, external_title: "Senior Engineer") }

  it "creates a valid path" do
    path = described_class.create!(from_title: from_title, to_title: to_title, path_type: "natural_progression")
    expect(path.path_type_label).to eq("Natural progression")
  end

  it "rejects self links" do
    path = described_class.new(from_title: from_title, to_title: from_title, path_type: "natural_progression")
    expect(path).not_to be_valid
    expect(path.errors[:base]).to include("cannot link a title to itself")
  end

  it "rejects outbound paths from end-cap titles" do
    from_title.update!(end_cap: true)
    path = described_class.new(from_title: from_title, to_title: to_title, path_type: "natural_progression")
    expect(path).not_to be_valid
    expect(path.errors[:base]).to include("end-cap titles cannot have outbound paths")
  end

  it "rejects circular references" do
    described_class.create!(from_title: from_title, to_title: to_title, path_type: "natural_progression")
    cycle = described_class.new(from_title: to_title, to_title: from_title, path_type: "parallel_progression")
    expect(cycle).not_to be_valid
    expect(cycle.errors[:base]).to include("this path would create a circular reference")
  end

  it "rejects duplicates" do
    described_class.create!(from_title: from_title, to_title: to_title, path_type: "natural_progression")
    dup = described_class.new(from_title: from_title, to_title: to_title, path_type: "parallel_progression")
    expect(dup).not_to be_valid
  end
end
