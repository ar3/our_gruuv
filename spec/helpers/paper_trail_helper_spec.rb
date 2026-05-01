require 'rails_helper'

RSpec.describe PaperTrailHelper, type: :helper do
  let(:organization) { create(:organization) }

  describe '#paper_trail_effective_changeset' do
    it 'returns deserialized attributes when PaperTrail changeset is empty but object_changes YAML exists' do
      PaperTrail.enabled = true
      assignment = create(:assignment, company: organization)
      assignment.update!(tagline: "#{assignment.tagline} revised")

      version = assignment.versions.order(created_at: :desc).first
      allow(version).to receive(:changeset).and_return({})

      raw = version.read_attribute(:object_changes)
      expect(raw).to be_present

      cs = helper.paper_trail_effective_changeset(version, Assignment)
      expect(cs.keys).to include('tagline')
    ensure
      PaperTrail.enabled = false
    end

    it 'prefers the normal PaperTrail changeset when it is present' do
      PaperTrail.enabled = true
      assignment = create(:assignment, company: organization)
      assignment.update!(tagline: "#{assignment.tagline} revised")

      version = assignment.versions.order(created_at: :desc).first
      cs = helper.paper_trail_effective_changeset(version, Assignment)
      expect(cs.keys).to include('tagline')
    ensure
      PaperTrail.enabled = false
    end
  end

  describe '#paper_trail_version_changes_popover_content' do
    it 'includes Field / Before / After headers and attribute rows' do
      PaperTrail.enabled = true
      assignment = create(:assignment, company: organization)
      assignment.update!(title: "#{assignment.title} X")

      version = assignment.versions.order(created_at: :desc).first
      cs = helper.paper_trail_effective_changeset(version, Assignment)
      html = helper.paper_trail_version_changes_popover_content(Assignment, version, changeset: cs)

      expect(html).to include('Before')
      expect(html).to include('After')
      expect(html).to include('Field')
    ensure
      PaperTrail.enabled = false
    end
  end
end
