# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::ListSitemap, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "returns permission-filtered sitemap sections with labels, paths, goals, and also_known_as" do
    result = described_class.call(context: context)

    expect(result.ok?).to be(true)
    expect(result.data[:page_count]).to be > 0
    expect(result.data[:sections]).to be_present

    pages = result.data[:sections].flat_map { |section| section[:pages] }
    sitemap_page = pages.find { |page| page[:label] == "Sitemap" }
    expect(sitemap_page).to include(
      :path,
      :section,
      :goal,
      :also_known_as
    )
    expect(sitemap_page[:also_known_as]).to include("sitemap")
    expect(sitemap_page[:path]).to include("/sitemap")
  end
end
