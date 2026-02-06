require 'rails_helper'

RSpec.describe S3::CsvUploader, type: :service do
  let(:bucket_name) { 'test-bulk-downloads-bucket' }
  let(:csv_content) { "Name,Email\nJohn Doe,john@example.com\n" }
  let(:filename) { 'test_file.csv' }
  let(:organization_id) { 123 }
  let(:download_type) { 'assignments' }
  let(:uploader) { described_class.new }

  before do
    # Stub ENV calls - need to stub BULK_DOWNLOADS_S3_BUCKET first, then allow others
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('BULK_DOWNLOADS_S3_BUCKET').and_return(bucket_name)
    allow(ENV).to receive(:[]).with('DEFAULT_S3_BUCKET').and_return(nil)
    allow(ENV).to receive(:[]).with('AWS_ACCESS_KEY_ID').and_return('test-access-key')
    allow(ENV).to receive(:[]).with('AWS_SECRET_ACCESS_KEY').and_return('test-secret-key')
    allow(ENV).to receive(:[]).with('AWS_REGION').and_return('us-east-1')
  end

  describe '#bucket_name' do
    it 'uses BULK_DOWNLOADS_S3_BUCKET when set' do
      allow(ENV).to receive(:[]).with('BULK_DOWNLOADS_S3_BUCKET').and_return('bulk-bucket')
      allow(ENV).to receive(:[]).with('DEFAULT_S3_BUCKET').and_return('default-bucket')
      expect(uploader.bucket_name).to eq('bulk-bucket')
    end

    it 'falls back to DEFAULT_S3_BUCKET when BULK_DOWNLOADS_S3_BUCKET is not set' do
      allow(ENV).to receive(:[]).with('BULK_DOWNLOADS_S3_BUCKET').and_return(nil)
      allow(ENV).to receive(:[]).with('DEFAULT_S3_BUCKET').and_return('default-bucket')
      expect(uploader.bucket_name).to eq('default-bucket')
    end

    it 'falls back to hardcoded default when neither env var is set' do
      allow(ENV).to receive(:[]).with('BULK_DOWNLOADS_S3_BUCKET').and_return(nil)
      allow(ENV).to receive(:[]).with('DEFAULT_S3_BUCKET').and_return(nil)
      expect(uploader.bucket_name).to eq('bulk-downloads.ourgruuv.com')
    end
  end

  describe '#upload' do
    let(:mock_s3_resource) { instance_double(Aws::S3::Resource) }
    let(:mock_bucket) { instance_double(Aws::S3::Bucket) }
    let(:mock_object) { instance_double(Aws::S3::Object) }

    before do
      allow(Aws::S3::Resource).to receive(:new).and_return(mock_s3_resource)
      allow(mock_s3_resource).to receive(:bucket).with(bucket_name).and_return(mock_bucket)
    end

    context 'when upload is successful' do
      it 'uploads CSV to S3 and returns s3_key and s3_url' do
        s3_key = "bulk-downloads/#{organization_id}/#{download_type}/test_file_#{Time.current.to_i}.csv"
        allow(mock_bucket).to receive(:object).and_return(mock_object)
        allow(mock_object).to receive(:put).and_return(true)

        result = uploader.upload(
          csv_content,
          filename: filename,
          organization_id: organization_id,
          download_type: download_type
        )

        expect(result).to have_key(:s3_key)
        expect(result).to have_key(:s3_url)
        expect(result[:s3_key]).to include("bulk-downloads/#{organization_id}/#{download_type}/")
        expect(result[:s3_url]).to include(result[:s3_key])
        expect(mock_object).to have_received(:put).with(
          hash_including(
            body: csv_content,
            acl: 'private',
            content_type: 'text/csv'
          )
        )
      end
    end

    context 'when upload fails' do
      it 'raises an error' do
        allow(mock_bucket).to receive(:object).and_return(mock_object)
        allow(mock_object).to receive(:put).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'S3 Error'))

        expect {
          uploader.upload(
            csv_content,
            filename: filename,
            organization_id: organization_id,
            download_type: download_type
          )
        }.to raise_error(Aws::S3::Errors::ServiceError)
      end

      it 'raises NoSuchBucket when the specified bucket does not exist' do
        allow(mock_bucket).to receive(:object).and_return(mock_object)
        allow(mock_object).to receive(:put).and_raise(
          Aws::S3::Errors::NoSuchBucket.new(nil, 'The specified bucket does not exist')
        )

        expect {
          uploader.upload(
            csv_content,
            filename: filename,
            organization_id: organization_id,
            download_type: download_type
          )
        }.to raise_error(Aws::S3::Errors::NoSuchBucket, 'The specified bucket does not exist')
      end
    end

    context 'when required parameters are missing' do
      it 'raises ArgumentError for missing csv_content' do
        expect {
          uploader.upload(nil, filename: filename, organization_id: organization_id, download_type: download_type)
        }.to raise_error(ArgumentError, 'CSV content is required')
      end

      it 'raises ArgumentError for missing filename' do
        expect {
          uploader.upload(csv_content, filename: nil, organization_id: organization_id, download_type: download_type)
        }.to raise_error(ArgumentError, 'Filename is required')
      end

      it 'raises ArgumentError for missing organization_id' do
        expect {
          uploader.upload(csv_content, filename: filename, organization_id: nil, download_type: download_type)
        }.to raise_error(ArgumentError, 'Organization ID is required')
      end

      it 'raises ArgumentError for missing download_type' do
        expect {
          uploader.upload(csv_content, filename: filename, organization_id: organization_id, download_type: nil)
        }.to raise_error(ArgumentError, 'Download type is required')
      end
    end
  end

  describe '#download' do
    let(:mock_s3_resource) { instance_double(Aws::S3::Resource) }
    let(:mock_bucket) { instance_double(Aws::S3::Bucket) }
    let(:mock_object) { instance_double(Aws::S3::Object) }
    let(:mock_response) { instance_double(Aws::S3::Types::GetObjectOutput, body: instance_double(StringIO, read: csv_content)) }
    let(:s3_key) { 'bulk-downloads/123/assignments/test_file.csv' }

    before do
      allow(Aws::S3::Resource).to receive(:new).and_return(mock_s3_resource)
      allow(mock_s3_resource).to receive(:bucket).with(bucket_name).and_return(mock_bucket)
      allow(mock_bucket).to receive(:object).with(s3_key).and_return(mock_object)
    end

    context 'when download is successful' do
      it 'downloads CSV from S3 and returns content' do
        allow(mock_object).to receive(:get).and_return(mock_response)

        result = uploader.download(s3_key)

        expect(result).to eq(csv_content)
        expect(mock_object).to have_received(:get)
      end
    end

    context 'when download fails' do
      it 'raises an error' do
        allow(mock_object).to receive(:get).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'S3 Error'))

        expect {
          uploader.download(s3_key)
        }.to raise_error(Aws::S3::Errors::ServiceError)
      end
    end

    context 'when s3_key is missing' do
      it 'raises ArgumentError' do
        expect {
          uploader.download(nil)
        }.to raise_error(ArgumentError, 'S3 key is required')
      end
    end
  end
end
