# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TerminologyHelper, type: :helper do
  describe 'clarity check-in labels' do
    it 'returns Clarity Hub' do
      expect(helper.clarity_hub_label).to eq('Clarity Hub')
    end

    it 'returns bulk clarity check-in label' do
      expect(helper.bulk_clarity_check_in_label).to eq('Bulk clarity check-in')
    end

    it 'interpolates review together count' do
      expect(helper.review_clarity_check_ins_together_label(count: 3)).to eq(
        'Review 3 clarity check-ins together'
      )
    end
  end

  describe 'confidence check labels' do
    it 'returns confidence check mode' do
      expect(helper.confidence_check_mode_label).to eq('Confidence check mode')
    end

    it 'returns save confidence check' do
      expect(helper.save_confidence_check_label).to eq('Save confidence check')
    end

    it 'interpolates last confidence check ago' do
      expect(helper.last_confidence_check_ago_label(time: '2 days')).to eq(
        'Last confidence check 2 days ago'
      )
    end
  end

  describe '1:1 labels' do
    it 'returns Weekly 1:1 without check-in' do
      expect(helper.weekly_1_1_label).to eq('Weekly 1:1')
      expect(helper.weekly_1_1_label).not_to include('check-in')
    end
  end

  describe '#terminology' do
    it 'loads every key defined under en.terminology' do
      keys = I18n.t('terminology').keys
      expect(keys).not_to be_empty
      keys.each do |key|
        expect(I18n.t("terminology.#{key}")).to be_present
      end
    end
  end
end
