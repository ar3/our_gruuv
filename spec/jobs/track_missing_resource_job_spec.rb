require 'rails_helper'

RSpec.describe TrackMissingResourceJob, type: :job do
  describe '#perform' do
    let(:path) { '/our/explore/choose_roles' }
    let(:person) { create(:person) }
    let(:ip_address) { '192.168.1.1' }
    let(:user_agent) { 'Mozilla/5.0' }
    let(:referrer) { 'https://example.com' }
    let(:request_method) { 'GET' }
    let(:query_string) { 'param=value' }

    context 'when creating a new missing resource' do
      it 'creates a new MissingResource' do
        expect {
          described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        }.to change(MissingResource, :count).by(1)

        resource = MissingResource.last
        expect(resource.path).to eq(path)
        expect(resource.request_count).to eq(1)
        expect(resource.first_seen_at).to be_present
        expect(resource.last_seen_at).to be_present
      end

      it 'creates a new MissingResourceRequest' do
        expect {
          described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        }.to change(MissingResourceRequest, :count).by(1)

        request = MissingResourceRequest.last
        expect(request.missing_resource.path).to eq(path)
        expect(request.person).to eq(person)
        expect(request.ip_address).to eq(ip_address)
        expect(request.request_count).to eq(1)
        expect(request.user_agent).to eq(user_agent)
        expect(request.referrer).to eq(referrer)
        expect(request.request_method).to eq(request_method)
        expect(request.query_string).to eq(query_string)
      end
    end

    context 'when updating an existing missing resource' do
      let!(:existing_resource) { create(:missing_resource, path: path, request_count: 5, last_seen_at: 1.day.ago) }

      it 'increments request_count' do
        expect {
          described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        }.not_to change(MissingResource, :count)

        existing_resource.reload
        expect(existing_resource.request_count).to eq(6)
      end

      it 'updates last_seen_at' do
        old_last_seen = existing_resource.last_seen_at
        sleep(0.1)
        described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        
        existing_resource.reload
        expect(existing_resource.last_seen_at).to be > old_last_seen
      end
    end

    context 'when updating an existing missing resource request' do
      let!(:missing_resource) { create(:missing_resource, path: path) }
      let!(:existing_request) do
        create(:missing_resource_request,
          missing_resource: missing_resource,
          person: person,
          ip_address: ip_address,
          request_count: 3,
          last_seen_at: 1.day.ago
        )
      end

      it 'increments request_count' do
        expect {
          described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        }.not_to change(MissingResourceRequest, :count)

        existing_request.reload
        expect(existing_request.request_count).to eq(4)
      end

      it 'updates metadata' do
        new_user_agent = 'New Agent'
        described_class.new.perform(path, person.id, ip_address, new_user_agent, referrer, request_method, query_string)
        
        existing_request.reload
        expect(existing_request.user_agent).to eq(new_user_agent)
        expect(existing_request.last_seen_at).to be > 1.day.ago
      end
    end

    context 'when person_id is nil (anonymous user)' do
      it 'creates MissingResourceRequest without person' do
        expect {
          described_class.new.perform(path, nil, ip_address, user_agent, referrer, request_method, query_string)
        }.to change(MissingResourceRequest, :count).by(1)

        request = MissingResourceRequest.last
        expect(request.person).to be_nil
        expect(request.ip_address).to eq(ip_address)
      end
    end

    context 'when an error occurs' do
      before do
        allow(MissingResource).to receive(:find_or_create_by).and_raise(ActiveRecord::RecordInvalid.new(MissingResource.new))
      end

      it 'logs the error and does not raise' do
        expect(Rails.logger).to receive(:error).at_least(:once)
        
        expect {
          described_class.new.perform(path, person.id, ip_address, user_agent, referrer, request_method, query_string)
        }.not_to raise_error
      end
    end
  end
end

