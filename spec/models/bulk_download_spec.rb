require 'rails_helper'

RSpec.describe BulkDownload, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:bulk_download) { build(:bulk_download, company: organization, downloaded_by: teammate) }

  describe 'associations' do
    it { should belong_to(:company).class_name('Organization') }
    it { should belong_to(:downloaded_by).class_name('CompanyTeammate') }
  end

  describe 'validations' do
    it { should validate_presence_of(:company) }
    it { should validate_presence_of(:downloaded_by) }
    it { should validate_presence_of(:download_type) }
    it { should validate_presence_of(:s3_key) }
    it { should validate_presence_of(:s3_url) }
    it { should validate_presence_of(:filename) }
  end

  describe 'scopes' do
    let!(:download1) { create(:bulk_download, :assignments, company: organization, downloaded_by: teammate, created_at: 2.days.ago) }
    let!(:download2) { create(:bulk_download, :assignments, company: organization, downloaded_by: teammate, created_at: 1.day.ago) }
    let!(:download3) { create(:bulk_download, :abilities, company: organization, downloaded_by: teammate, created_at: 3.days.ago) }
    let(:other_org) { create(:organization, :company) }
    let!(:download4) { create(:bulk_download, :assignments, company: other_org, downloaded_by: teammate) }

    describe '.by_type' do
      it 'returns downloads of the specified type' do
        expect(described_class.by_type('assignments')).to include(download1, download2)
        expect(described_class.by_type('assignments')).not_to include(download3)
      end
    end

    describe '.recent' do
      it 'returns downloads ordered by created_at desc' do
        recent = described_class.recent.to_a
        expect(recent.first.created_at).to be > recent.second.created_at
        expect(recent.second.created_at).to be > recent.third.created_at
        expect(recent.map(&:id)).to include(download1.id, download2.id, download3.id)
      end
    end

    describe '.for_organization' do
      it 'returns downloads for the specified company' do
        expect(described_class.for_organization(organization)).to include(download1, download2, download3)
        expect(described_class.for_organization(organization)).not_to include(download4)
      end
    end
  end
end
