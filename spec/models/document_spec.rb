# frozen_string_literal: true

require "rails_helper"

RSpec.describe Document, type: :model do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, :unassigned_employee, organization: organization) }

  describe "validations" do
    it "requires title, kind, and owner in the same organization" do
      document = described_class.new(organization: organization, title: "Ops SOP", kind: "how_to")
      expect(document).not_to be_valid
      expect(document.errors[:owner]).to be_present

      document.owner = teammate
      document.owner_type = "CompanyTeammate"
      expect(document).to be_valid
    end
  end

  describe "staleness_exempt?" do
    it "exempts dated kinds from owner re-verify style staleness" do
      announcement = build(:document, organization: organization, owner: teammate, kind: "announcement")
      training = build(:document, organization: organization, owner: teammate, kind: "training_record")
      generic = build(:document, organization: organization, owner: teammate, kind: "generic")
      how_to = build(:document, organization: organization, owner: teammate, kind: "how_to")

      expect(announcement).to be_staleness_exempt
      expect(training).to be_staleness_exempt
      expect(generic).to be_staleness_exempt
      expect(how_to).not_to be_staleness_exempt
    end
  end

  describe "KIND_GROUPS" do
    it "has exactly three kinds in each category" do
      expect(described_class::KIND_GROUPS.map { |g| g[:kinds].size }).to all(eq(3))
      expect(described_class::KIND_GROUPS.flat_map { |g| g[:kinds] }).to match_array(described_class::KINDS)
    end
  end

  describe "#sync body to text block" do
    it "creates a text block from body on save" do
      document = create(:document, organization: organization, owner: teammate, body: "Step one")
      expect(document.blocks.count).to eq(1)
      expect(document.blocks.first.block_type).to eq("text")
      expect(document.blocks.first.content).to eq("Step one")
      expect(document.blocks.first.uuid).to be_present
    end

    it "updates the existing text block when body changes" do
      document = create(:document, organization: organization, owner: teammate, body: "Before")
      document.update!(body: "After")
      expect(document.blocks.count).to eq(1)
      expect(document.reload.blocks.first.content).to eq("After")
    end
  end

  describe "assignment links" do
    it "can link the same document to multiple assignments" do
      a1 = create(:assignment, company: organization, title: "Alpha Work")
      a2 = create(:assignment, company: organization, title: "Beta Work")
      document = create(:document, organization: organization, owner: teammate, body: "Shared SOP")
      document.update!(assignment_ids_to_link: [a1.id, a2.id])

      expect(document.linked_assignments).to contain_exactly(a1, a2)
      expect(a1.clarity_documents).to include(document)
      expect(a2.clarity_documents).to include(document)
    end
  end

  describe "#to_markdown" do
    it "includes title and block markers" do
      document = create(:document, organization: organization, owner: teammate, title: "Onboarding", body: "Do the thing")
      markdown = document.to_markdown
      expect(markdown).to include("# Onboarding")
      expect(markdown).to include("<!-- block:#{document.blocks.first.uuid} -->")
      expect(markdown).to include("Do the thing")
    end
  end
end
