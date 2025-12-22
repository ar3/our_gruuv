require 'rails_helper'

RSpec.describe S3::Client, type: :service do
  let(:bucket_name) { 'test-slack-events-bucket' }
  let(:file_path) { 'slack-events/development/test-org/message/2024/01/15/t_10_30_45_0000.json' }
  let(:hash_object) { { 'type' => 'event_callback', 'event' => { 'type' => 'message' } } }
  let(:s3_client) { described_class.new }

  before do
    allow(ENV).to receive(:[]).with('SLACK_EVENTS_S3_BUCKET').and_return(bucket_name)
    allow(ENV).to receive(:[]).with('AWS_ACCESS_KEY_ID').and_return('test-access-key')
    allow(ENV).to receive(:[]).with('AWS_SECRET_ACCESS_KEY').and_return('test-secret-key')
    allow(ENV).to receive(:[]).with('AWS_REGION').and_return('us-east-1')
  end

  describe '#save_json_to_s3' do
    let(:mock_s3_resource) { instance_double(Aws::S3::Resource) }
    let(:mock_bucket) { instance_double(Aws::S3::Bucket) }
    let(:mock_object) { instance_double(Aws::S3::Object) }

    before do
      allow(Aws::S3::Resource).to receive(:new).and_return(mock_s3_resource)
      allow(mock_s3_resource).to receive(:bucket).with(bucket_name).and_return(mock_bucket)
      allow(mock_bucket).to receive(:object).with(file_path).and_return(mock_object)
    end

    context 'when S3 save is successful' do
      before do
        allow(mock_object).to receive(:put).with(body: hash_object.to_json).and_return(true)
      end

      it 'saves JSON to S3 successfully' do
        result = s3_client.save_json_to_s3(
          full_file_path_and_name: file_path,
          hash_object: hash_object
        )

        expect(result).to be true
        expect(mock_object).to have_received(:put).with(body: hash_object.to_json)
      end
    end

    context 'when S3 save fails' do
      before do
        allow(mock_object).to receive(:put).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'S3 Error'))
      end

      it 'raises an error' do
        expect {
          s3_client.save_json_to_s3(
            full_file_path_and_name: file_path,
            hash_object: hash_object
          )
        }.to raise_error(Aws::S3::Errors::ServiceError)
      end
    end

    context 'when bucket name is not configured' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_EVENTS_S3_BUCKET').and_return(nil)
      end

      it 'raises an error' do
        expect {
          s3_client.save_json_to_s3(
            full_file_path_and_name: file_path,
            hash_object: hash_object
          )
        }.to raise_error(ArgumentError, /bucket name/)
      end
    end
  end
end

