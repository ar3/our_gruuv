require 'rails_helper'

RSpec.describe PositionDecorator do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { build(:position, title: title, position_level: position_level, semantic_version: '2.3.4') }
  let(:decorator) { PositionDecorator.new(position) }

  describe '#new_version_options' do
    it 'returns array of version options for new records' do
      options = decorator.new_version_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(3)
      expect(options.map { |o| o[:value] }).to contain_exactly('ready', 'nearly_ready', 'early_draft')
    end
  end

  describe '#edit_version_options' do
    it 'calculates correct version for fundamental change' do
      position.save!
      options = decorator.edit_version_options
      fundamental_option = options.find { |o| o[:value] == 'fundamental' }
      expect(fundamental_option[:version_text]).to eq('Version 3.0.0')
    end

    it 'calculates correct version for clarifying change' do
      position.save!
      options = decorator.edit_version_options
      clarifying_option = options.find { |o| o[:value] == 'clarifying' }
      expect(clarifying_option[:version_text]).to eq('Version 2.4.0')
    end

    it 'calculates correct version for insignificant change' do
      position.save!
      options = decorator.edit_version_options
      insignificant_option = options.find { |o| o[:value] == 'insignificant' }
      expect(insignificant_option[:version_text]).to eq('Version 2.3.5')
    end
  end

  describe '#version_section_title_for_context' do
    it 'returns correct title for new records' do
      expect(decorator.version_section_title_for_context).to eq('Position Status & Version')
    end

    it 'returns correct title for existing records' do
      position.save!
      expect(decorator.version_section_title_for_context).to eq('Change Type & Version')
    end
  end
end
