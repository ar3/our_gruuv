require 'rails_helper'

RSpec.describe Companies::RefreshSlackChannelsJob, type: :job do
  let(:company) { create(:organization, :company) }
  let(:slack_config) { create(:slack_configuration, organization: company) }

  before do
    slack_config
  end

  describe 'basic functionality' do
    it 'can be instantiated and run' do
      job = described_class.new
      expect(job).to be_a(Companies::RefreshSlackChannelsJob)
      
      # Test that the job can be performed without errors
      expect { job.perform(company.id) }.not_to raise_error
    end

    it 'has the required methods' do
      job = described_class.new
      expect(job).to respond_to(:perform)
    end
  end

  describe '#perform' do
    context 'when company has Slack configured' do
      it 'calls the SlackChannelsService' do
        service = instance_double(SlackChannelsService)
        allow(SlackChannelsService).to receive(:new).and_return(service)
        allow(service).to receive(:refresh_channels).and_return(true)

        result = described_class.perform_and_get_result(company.id)
        
        expect(result).to be true
        expect(service).to have_received(:refresh_channels)
      end
    end

    context 'when company does not have Slack configured' do
      before { slack_config.destroy }

      it 'returns false' do
        result = described_class.perform_and_get_result(company.id)
        expect(result).to be false
      end
    end
  end
end 