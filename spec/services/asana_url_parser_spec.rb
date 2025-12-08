require 'rails_helper'

RSpec.describe AsanaUrlParser do
  describe '.extract_project_id' do
    it 'extracts project ID from /project/{id} pattern' do
      url = 'https://app.asana.com/1/11521292414839/project/1207208655427739/list/1207208749360150'
      expect(AsanaUrlParser.extract_project_id(url)).to eq('1207208655427739')
    end

    it 'extracts project ID from /project/{id} pattern without list' do
      url = 'https://app.asana.com/1/11521292414839/project/1207208655427739'
      expect(AsanaUrlParser.extract_project_id(url)).to eq('1207208655427739')
    end

    it 'extracts project ID from /0/{id} pattern' do
      url = 'https://app.asana.com/0/123456/789'
      expect(AsanaUrlParser.extract_project_id(url)).to eq('123456')
    end

    it 'extracts project ID from /0/{id} pattern without section' do
      url = 'https://app.asana.com/0/123456'
      expect(AsanaUrlParser.extract_project_id(url)).to eq('123456')
    end

    it 'prefers /project/{id} pattern over /0/{id} pattern' do
      # This shouldn't happen in real URLs, but tests the priority
      url = 'https://app.asana.com/0/123456/project/789012'
      expect(AsanaUrlParser.extract_project_id(url)).to eq('789012')
    end

    it 'returns nil for non-Asana URLs' do
      url = 'https://example.com/project/123'
      expect(AsanaUrlParser.extract_project_id(url)).to be_nil
    end

    it 'returns nil for blank URLs' do
      expect(AsanaUrlParser.extract_project_id('')).to be_nil
      expect(AsanaUrlParser.extract_project_id(nil)).to be_nil
    end

    it 'returns nil for URLs without project ID' do
      url = 'https://app.asana.com/1/11521292414839'
      expect(AsanaUrlParser.extract_project_id(url)).to be_nil
    end
  end
end

