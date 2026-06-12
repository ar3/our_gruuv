require "rails_helper"

RSpec.describe OrganizationSitemap::Builder, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }
  let(:context) do
    OrganizationSitemap::Context.new(
      organization: organization,
      teammate: teammate
    )
  end
  let(:builder) { described_class.new(context: context) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe "#entries" do
    it "dedupes pages with the same path" do
      paths = builder.entries.map(&:path)
      expect(paths).to eq(paths.uniq)
    end

    it "includes the sitemap page itself" do
      labels = builder.entries.map(&:label)
      expect(labels).to include("Sitemap")
    end
  end

  describe "#search" do
    it "finds the abilities page by synonym" do
      results = builder.search("abilities")
      labels = results.map(&:label)
      expect(labels).to include("Milestones & Abilities")
    end

    it "finds the 1:1 hub for the current teammate only" do
      results = builder.search("one on one")
      labels = results.map(&:label)
      expect(labels).to include("1:1 Hub")
    end
  end
end
