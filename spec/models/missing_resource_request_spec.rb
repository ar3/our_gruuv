require 'rails_helper'

RSpec.describe MissingResourceRequest, type: :model do
  describe 'associations' do
    it { should belong_to(:missing_resource) }
    it { should belong_to(:person).optional }
  end

  describe 'validations' do
    it { should validate_presence_of(:missing_resource) }
    it { should validate_presence_of(:ip_address) }
    it { should validate_presence_of(:request_count) }
    it { should validate_numericality_of(:request_count).is_greater_than_or_equal_to(1) }
  end

  describe 'scopes' do
    let(:person) { create(:person) }
    let(:missing_resource) { create(:missing_resource) }
    let!(:request1) { create(:missing_resource_request, person: person, missing_resource: missing_resource) }
    let!(:request2) { create(:missing_resource_request, person: nil, ip_address: '192.168.1.1', missing_resource: missing_resource) }
    let!(:request3) { create(:missing_resource_request, person: person, missing_resource: create(:missing_resource)) }

    describe '.for_person' do
      it 'returns only requests for the specified person' do
        expect(MissingResourceRequest.for_person(person).to_a).to contain_exactly(request1, request3)
      end
    end

    describe '.for_ip' do
      it 'returns only requests for the specified IP' do
        expect(MissingResourceRequest.for_ip('192.168.1.1').to_a).to contain_exactly(request2)
      end
    end

    describe '.anonymous' do
      it 'returns only requests without a person' do
        expect(MissingResourceRequest.anonymous.to_a).to contain_exactly(request2)
      end
    end

    describe '.authenticated' do
      it 'returns only requests with a person' do
        expect(MissingResourceRequest.authenticated.to_a).to contain_exactly(request1, request3)
      end
    end
  end

  describe 'unique constraint' do
    let(:missing_resource) { create(:missing_resource) }
    let(:person) { create(:person) }
    let(:ip_address) { '192.168.1.1' }

    it 'enforces uniqueness of missing_resource_id, person_id, and ip_address combination' do
      create(:missing_resource_request, missing_resource: missing_resource, person: person, ip_address: ip_address)
      
      expect {
        create(:missing_resource_request, missing_resource: missing_resource, person: person, ip_address: ip_address)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'allows same combination for different missing resources' do
      resource2 = create(:missing_resource)
      create(:missing_resource_request, missing_resource: missing_resource, person: person, ip_address: ip_address)
      
      expect {
        create(:missing_resource_request, missing_resource: resource2, person: person, ip_address: ip_address)
      }.not_to raise_error
    end

    it 'allows same missing_resource and IP with different person' do
      person2 = create(:person)
      create(:missing_resource_request, missing_resource: missing_resource, person: person, ip_address: ip_address)
      
      expect {
        create(:missing_resource_request, missing_resource: missing_resource, person: person2, ip_address: ip_address)
      }.not_to raise_error
    end
  end

  describe '#increment_request_count!' do
    let(:request) { create(:missing_resource_request, request_count: 5, last_seen_at: 1.day.ago) }

    it 'increments request_count' do
      expect {
        request.increment_request_count!
      }.to change { request.reload.request_count }.by(1)
    end

    it 'updates last_seen_at' do
      old_last_seen = request.last_seen_at
      sleep(0.1)
      request.increment_request_count!
      expect(request.reload.last_seen_at).to be > old_last_seen
    end
  end

  describe '#update_metadata!' do
    let(:request) { create(:missing_resource_request) }

    it 'updates all metadata fields' do
      request.update_metadata!(
        user_agent: 'New Agent',
        referrer: 'https://example.com',
        request_method: 'POST',
        query_string: 'param=value'
      )

      request.reload
      expect(request.user_agent).to eq('New Agent')
      expect(request.referrer).to eq('https://example.com')
      expect(request.request_method).to eq('POST')
      expect(request.query_string).to eq('param=value')
    end
  end
end

