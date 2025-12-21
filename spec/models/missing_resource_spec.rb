require 'rails_helper'

RSpec.describe MissingResource, type: :model do
  describe 'associations' do
    it { should have_many(:missing_resource_requests).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:path) }
    it { should validate_uniqueness_of(:path) }
    it { should validate_presence_of(:request_count) }
    it { should validate_numericality_of(:request_count).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    let!(:resource1) { create(:missing_resource, path: '/path1', request_count: 10, last_seen_at: 3.days.ago) }
    let!(:resource2) { create(:missing_resource, path: '/path2', request_count: 5, last_seen_at: 1.day.ago) }
    let!(:resource3) { create(:missing_resource, path: '/path3', request_count: 15, last_seen_at: 2.days.ago) }
    let!(:resource_with_suggestion) { create(:missing_resource, path: '/path4', suggested_redirect_path: '/redirect') }

    describe '.most_requested' do
      it 'orders by request_count descending, then last_seen_at descending' do
        expect(MissingResource.most_requested.to_a).to eq([resource3, resource1, resource2, resource_with_suggestion])
      end
    end

    describe '.recent' do
      it 'orders by last_seen_at descending' do
        expect(MissingResource.recent.to_a).to eq([resource2, resource3, resource1, resource_with_suggestion])
      end
    end

    describe '.with_suggestions' do
      it 'returns only resources with suggested_redirect_path' do
        expect(MissingResource.with_suggestions.to_a).to contain_exactly(resource_with_suggestion)
      end
    end
  end

  describe '#increment_request_count!' do
    let(:resource) { create(:missing_resource, request_count: 5, last_seen_at: 1.day.ago) }

    it 'increments request_count' do
      expect {
        resource.increment_request_count!
      }.to change { resource.reload.request_count }.by(1)
    end

    it 'updates last_seen_at' do
      old_last_seen = resource.last_seen_at
      sleep(0.1)
      resource.increment_request_count!
      expect(resource.reload.last_seen_at).to be > old_last_seen
    end
  end

  describe '#update_last_seen!' do
    let(:resource) { create(:missing_resource, last_seen_at: 1.day.ago) }

    it 'updates last_seen_at to current time' do
      old_last_seen = resource.last_seen_at
      sleep(0.1)
      resource.update_last_seen!
      expect(resource.reload.last_seen_at).to be > old_last_seen
    end
  end
end

