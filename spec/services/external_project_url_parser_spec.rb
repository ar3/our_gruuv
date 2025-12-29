require 'rails_helper'

RSpec.describe ExternalProjectUrlParser do
  describe '.detect_source' do
    it 'detects Asana URLs' do
      expect(ExternalProjectUrlParser.detect_source('https://app.asana.com/0/123456/789')).to eq('asana')
      expect(ExternalProjectUrlParser.detect_source('https://asana.com/0/123456')).to eq('asana')
    end

    it 'detects Jira URLs' do
      expect(ExternalProjectUrlParser.detect_source('https://company.jira.com/browse/PROJECT-123')).to eq('jira')
    end

    it 'detects Linear URLs' do
      expect(ExternalProjectUrlParser.detect_source('https://linear.app/team/project/issue/PRO-123')).to eq('linear')
    end

    it 'returns nil for unknown URLs' do
      expect(ExternalProjectUrlParser.detect_source('https://example.com')).to be_nil
      expect(ExternalProjectUrlParser.detect_source(nil)).to be_nil
    end
  end

  describe '.extract_project_id' do
    it 'extracts Asana project ID' do
      url = 'https://app.asana.com/0/123456/789'
      expect(ExternalProjectUrlParser.extract_project_id(url, 'asana')).to eq('123456')
    end

    it 'extracts Jira project ID' do
      url = 'https://company.jira.com/browse/PROJECT-123'
      expect(ExternalProjectUrlParser.extract_project_id(url, 'jira')).to eq('PROJECT')
    end

    it 'extracts Linear project ID' do
      url = 'https://linear.app/team/project/issue/PRO-123'
      expect(ExternalProjectUrlParser.extract_project_id(url, 'linear')).to eq('PRO')
    end

    it 'returns nil for invalid URLs' do
      expect(ExternalProjectUrlParser.extract_project_id('invalid', 'asana')).to be_nil
      expect(ExternalProjectUrlParser.extract_project_id(nil, 'asana')).to be_nil
    end
  end

  describe '.valid_project_url?' do
    it 'validates Asana URLs' do
      expect(ExternalProjectUrlParser.valid_project_url?('https://app.asana.com/0/123', 'asana')).to be true
      expect(ExternalProjectUrlParser.valid_project_url?('https://example.com', 'asana')).to be false
    end

    it 'validates Jira URLs' do
      expect(ExternalProjectUrlParser.valid_project_url?('https://company.jira.com', 'jira')).to be true
      expect(ExternalProjectUrlParser.valid_project_url?('https://example.com', 'jira')).to be false
    end

    it 'validates Linear URLs' do
      expect(ExternalProjectUrlParser.valid_project_url?('https://linear.app/team', 'linear')).to be true
      expect(ExternalProjectUrlParser.valid_project_url?('https://example.com', 'linear')).to be false
    end
  end
end

