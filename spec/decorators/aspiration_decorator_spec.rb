require 'rails_helper'

RSpec.describe AspirationDecorator do
  let(:organization) { create(:organization) }
  let(:aspiration) { build(:aspiration, company: organization, semantic_version: '1.2.3') }
  let(:decorator) { AspirationDecorator.new(aspiration) }

  describe '#new_version_options' do
    it 'returns array of version options for new records' do
      options = decorator.new_version_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(3)
      expect(options.map { |o| o[:value] }).to contain_exactly('ready', 'nearly_ready', 'early_draft')
    end

    it 'includes correct version text for ready' do
      options = decorator.new_version_options
      ready_option = options.find { |o| o[:value] == 'ready' }
      expect(ready_option[:version_text]).to eq('Version 1.0.0')
    end
  end

  describe '#edit_version_options' do
    it 'returns array of version options for existing records' do
      aspiration.save!
      options = decorator.edit_version_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(3)
      expect(options.map { |o| o[:value] }).to contain_exactly('fundamental', 'clarifying', 'insignificant')
    end

    it 'calculates correct version for fundamental change' do
      aspiration.save!
      options = decorator.edit_version_options
      fundamental_option = options.find { |o| o[:value] == 'fundamental' }
      expect(fundamental_option[:version_text]).to eq('Version 2.0.0')
    end

    it 'calculates correct version for clarifying change' do
      aspiration.save!
      options = decorator.edit_version_options
      clarifying_option = options.find { |o| o[:value] == 'clarifying' }
      expect(clarifying_option[:version_text]).to eq('Version 1.3.0')
    end

    it 'calculates correct version for insignificant change' do
      aspiration.save!
      options = decorator.edit_version_options
      insignificant_option = options.find { |o| o[:value] == 'insignificant' }
      expect(insignificant_option[:version_text]).to eq('Version 1.2.4')
    end
  end

  describe '#version_section_title_for_context' do
    it 'returns correct title for new records' do
      expect(decorator.version_section_title_for_context).to eq('Aspiration Status & Version')
    end

    it 'returns correct title for existing records' do
      aspiration.save!
      expect(decorator.version_section_title_for_context).to eq('Change Type & Version')
    end
  end

  describe '#version_section_description_for_context' do
    it 'returns correct description for new records' do
      description = decorator.version_section_description_for_context
      expect(description).to include('readiness level')
      expect(description).to include('aspiration')
    end

    it 'returns correct description for existing records' do
      aspiration.save!
      description = decorator.version_section_description_for_context
      expect(description).to include('Current version: 1.2.3')
      expect(description).to include('type of change')
    end
  end
end

