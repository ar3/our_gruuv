require 'rails_helper'

RSpec.describe SlackGroupsService do
  let(:organization) { create(:organization, :company) }
  let(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:service) { described_class.new(organization) }
  let(:mock_slack_service) { instance_double(SlackService) }

  before do
    slack_config
    allow(SlackService).to receive(:new).with(organization).and_return(mock_slack_service)
  end

  describe '#refresh_groups' do
    context 'when Slack is not configured' do
      before do
        allow(organization).to receive(:slack_configured?).and_return(false)
      end

      it 'returns false' do
        result = service.refresh_groups
        expect(result).to be false
      end
    end

    context 'when Slack is configured' do
      let(:groups) do
        [
          {
            'id' => 'S123456',
            'name' => 'Engineering',
            'handle' => 'engineering'
          },
          {
            'id' => 'S789012',
            'name' => 'Product',
            'handle' => 'product'
          }
        ]
      end

      before do
        allow(mock_slack_service).to receive(:list_groups).and_return(groups)
      end

      it 'refreshes groups and returns true' do
        result = service.refresh_groups
        expect(result).to be true
        
        group_objects = organization.third_party_objects.where(third_party_source: 'slack', third_party_object_type: 'group')
        expect(group_objects.count).to eq(2)
        expect(group_objects.pluck(:third_party_id)).to include('S123456', 'S789012')
      end

      it 'marks deleted groups' do
        # Create an existing group
        existing_group = create(:third_party_object, :slack_group, organization: organization, third_party_id: 'S999999')
        
        result = service.refresh_groups
        expect(result).to be true
        
        existing_group.reload
        expect(existing_group.deleted_at).to be_present
      end

      it 'updates existing groups' do
        existing_group = create(:third_party_object, :slack_group, organization: organization, third_party_id: 'S123456', display_name: 'Old Name')
        
        result = service.refresh_groups
        expect(result).to be true
        
        existing_group.reload
        expect(existing_group.display_name).to eq('Engineering')
        expect(existing_group.deleted_at).to be_nil
      end
    end

    context 'when API call fails' do
      before do
        allow(mock_slack_service).to receive(:list_groups).and_raise(StandardError.new('API Error'))
      end

      it 'returns false' do
        result = service.refresh_groups
        expect(result).to be false
      end
    end

    context 'when no groups are returned' do
      before do
        allow(mock_slack_service).to receive(:list_groups).and_return([])
      end

      it 'returns false' do
        result = service.refresh_groups
        expect(result).to be false
      end
    end
  end
end

