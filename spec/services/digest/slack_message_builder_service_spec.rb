# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::SlackMessageBuilderService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
  end

  describe '#main_message' do
    it 'returns hash with :blocks and :text' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:blocks]).to be_an(Array)
      expect(result[:text]).to be_a(String)
    end

    it 'uses company label for get_shit_done in the message when no items' do
      create(:company_label_preference, company: organization.root_company || organization, label_key: 'get_shit_done', label_value: 'Action Items')
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      expect(result[:text]).to include('Action Items')
    end

    it 'includes a link to configure digest in blocks' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.main_message

      context_block = result[:blocks].find { |b| b[:type] == 'context' }
      expect(context_block).to be_present
      expect(context_block.dig(:elements, 0, :text)).to include('Digest settings').or include('digest')
    end
  end

  describe '#thread1_gsd_list' do
    it 'returns hash with :blocks and :text' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.thread1_gsd_list

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:text]).to include('All clear:').or be_present
    end
  end

  describe '#thread2_about_me' do
    it 'returns hash with :blocks and :text including About Me title' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.thread2_about_me

      expect(result).to have_key(:blocks)
      expect(result).to have_key(:text)
      expect(result[:text]).to include("Let's look at your About Me page")
    end
  end

  describe '#short_summary_for_sms' do
    it 'returns a plain string suitable for SMS' do
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.short_summary_for_sms

      expect(result).to be_a(String)
      expect(result).not_to include('*')
    end

    it 'uses company label for get_shit_done in the summary' do
      create(:company_label_preference, company: organization.root_company || organization, label_key: 'get_shit_done', label_value: 'My List')
      # Stub so we get the "all clear" branch which includes the GSD label
      gsd_items = { total_pending: 0, observable_moments: [], maap_snapshots: [], observation_drafts: [], goals_needing_check_in: [], check_ins_awaiting_input: [] }
      allow(GetShitDoneQueryService).to receive(:new).and_return(instance_double(GetShitDoneQueryService, all_pending_items: gsd_items))
      allow(Digest::AboutMeContentService).to receive(:new).and_return(instance_double(Digest::AboutMeContentService, sections: []))
      builder = described_class.new(teammate: teammate, organization: organization)
      result = builder.short_summary_for_sms

      expect(result).to include('My List')
    end
  end
end
