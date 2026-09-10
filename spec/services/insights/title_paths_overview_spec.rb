# frozen_string_literal: true

require "rails_helper"

RSpec.describe Insights::TitlePathsOverview do
  let(:organization) { create(:organization) }
  let(:major_level_1) { create(:position_major_level, major_level: 1, set_name: "Eng-#{SecureRandom.hex(4)}") }
  let(:major_level_3) { create(:position_major_level, major_level: 3, set_name: "Eng-#{SecureRandom.hex(4)}") }
  let(:parent_dept) { create(:department, company: organization, name: "Engineering") }
  let(:child_dept) { create(:department, company: organization, name: "Platform", parent_department: parent_dept) }
  let(:other_dept) { create(:department, company: organization, name: "Sales") }

  let!(:eng_title) do
    create(:title, company: organization, position_major_level: major_level_1, department: parent_dept, external_title: "Engineer")
  end
  let!(:platform_title) do
    create(:title, company: organization, position_major_level: major_level_1, department: child_dept, external_title: "Platform Eng")
  end
  let!(:sales_title) do
    create(:title, company: organization, position_major_level: major_level_3, department: other_dept, external_title: "AE")
  end
  let!(:orphan_title) do
    create(:title, company: organization, position_major_level: major_level_1, department: parent_dept, external_title: "Orphan")
  end
  let!(:end_cap_title) do
    create(:title, company: organization, position_major_level: major_level_3, department: parent_dept, external_title: "CEO", end_cap: true)
  end

  before do
    create(:title_path, from_title: eng_title, to_title: sales_title, path_type: "natural_progression")
    create(:title_path, from_title: platform_title, to_title: eng_title, path_type: "parallel_progression")
  end

  it "counts connected (path or end-cap) vs unconnected titles" do
    result = described_class.call(organization: organization)

    expect(result.connected_count).to eq(4) # eng, platform, sales, end_cap
    expect(result.unconnected_count).to eq(1) # orphan
  end

  it "only graphs titles that participate in a path (not orphans or isolated end-caps)" do
    result = described_class.call(organization: organization)

    node_ids = result.elements.select { |e| e[:group] == "nodes" }.map { |e| e.dig(:data, :id) }
    expect(node_ids).to contain_exactly("title-#{eng_title.id}", "title-#{platform_title.id}", "title-#{sales_title.id}")
    expect(node_ids).not_to include("title-#{orphan_title.id}", "title-#{end_cap_title.id}")
  end

  it "places nodes in columns by major level (L1 left, higher right)" do
    result = described_class.call(organization: organization)

    eng_node = result.elements.find { |e| e.dig(:data, :id) == "title-#{eng_title.id}" }
    sales_node = result.elements.find { |e| e.dig(:data, :id) == "title-#{sales_title.id}" }

    expect(eng_node[:position][:x]).to eq(0)
    expect(sales_node[:position][:x]).to eq(described_class::COLUMN_WIDTH * 2)
    expect(eng_node.dig(:data, :majorLevel)).to eq(1)
    expect(sales_node.dig(:data, :majorLevel)).to eq(3)
  end

  it "builds colored edges and g6 payload with the same positions" do
    result = described_class.call(organization: organization)

    edges = result.elements.select { |e| e[:group] == "edges" }
    expect(edges.size).to eq(2)
    expect(edges.map { |e| e.dig(:data, :lineColor) }).to all(be_present)
    expect(result.g6_graph_data[:nodes].size).to eq(3)
    expect(result.g6_graph_data[:nodes].first[:style]).to include(:x, :y, :labelText, :labelPlacement)
    expect(result.g6_graph_data[:nodes].first[:style][:labelPlacement]).to eq("center")
    expect(result.g6_graph_data[:nodes].first[:style][:labelText]).to be_present
  end

  it "filters by department hierarchy and includes external path neighbors" do
    result = described_class.call(organization: organization, department_id: parent_dept.id)

    node_ids = result.elements.select { |e| e[:group] == "nodes" }.map { |e| e.dig(:data, :id) }

    expect(node_ids).to include("title-#{eng_title.id}", "title-#{platform_title.id}", "title-#{sales_title.id}")
    expect(node_ids).not_to include("title-#{orphan_title.id}")
    expect(result.connected_count).to eq(3) # eng, platform, end_cap in hierarchy
    expect(result.unconnected_count).to eq(1) # orphan

    sales_node = result.elements.find { |e| e.dig(:data, :id) == "title-#{sales_title.id}" }
    expect(sales_node.dig(:data, :highlightTier)).to eq("external")
  end
end
