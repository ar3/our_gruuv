require 'rails_helper'

RSpec.describe BulkDownloadPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:other_organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: organization) }
  let(:other_teammate) { create(:company_teammate, organization: organization) }
  let(:admin_teammate) { create(:company_teammate, organization: organization) }
  let(:admin_person) { create(:person, :admin) }
  let(:employment_teammate) { create(:company_teammate, organization: organization, can_manage_employment: true) }
  
  let(:bulk_download) { create(:bulk_download, company: organization, downloaded_by: teammate) }
  let(:other_bulk_download) { create(:bulk_download, company: organization, downloaded_by: other_teammate) }
  let(:other_org_download) { create(:bulk_download, company: other_organization, downloaded_by: teammate) }

  before do
    admin_teammate.update(person: admin_person)
  end

  subject { described_class }

  permissions :show? do
    it 'allows viewing download history for any teammate' do
      expect(subject).to permit(teammate, bulk_download)
    end

    it 'allows viewing download history for admin' do
      expect(subject).to permit(admin_teammate, bulk_download)
    end

    it 'denies viewing download history for different organization' do
      expect(subject).not_to permit(teammate, other_org_download)
    end
  end

  permissions :download? do
    context 'when user is og_admin' do
      it 'allows download of any file' do
        expect(subject).to permit(admin_teammate, bulk_download)
        expect(subject).to permit(admin_teammate, other_bulk_download)
      end
    end

    context 'when user can_manage_employment' do
      it 'allows download of any file' do
        expect(subject).to permit(employment_teammate, bulk_download)
        expect(subject).to permit(employment_teammate, other_bulk_download)
      end
    end

    context 'when user is regular teammate' do
      it 'allows download of own file' do
        expect(subject).to permit(teammate, bulk_download)
      end

      it 'denies download of other user\'s file' do
        expect(subject).not_to permit(teammate, other_bulk_download)
      end
    end

    context 'when download is from different organization' do
      it 'denies download' do
        expect(subject).not_to permit(teammate, other_org_download)
      end
    end
  end
end
