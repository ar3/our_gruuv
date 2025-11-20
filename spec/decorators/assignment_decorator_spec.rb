require 'rails_helper'

RSpec.describe AssignmentDecorator do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { build(:assignment, company: organization, semantic_version: '3.4.5') }
  let(:decorator) { AssignmentDecorator.new(assignment) }

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
      assignment.save!
      options = decorator.edit_version_options
      fundamental_option = options.find { |o| o[:value] == 'fundamental' }
      expect(fundamental_option[:version_text]).to eq('Version 4.0.0')
    end

    it 'calculates correct version for clarifying change' do
      assignment.save!
      options = decorator.edit_version_options
      clarifying_option = options.find { |o| o[:value] == 'clarifying' }
      expect(clarifying_option[:version_text]).to eq('Version 3.5.0')
    end

    it 'calculates correct version for insignificant change' do
      assignment.save!
      options = decorator.edit_version_options
      insignificant_option = options.find { |o| o[:value] == 'insignificant' }
      expect(insignificant_option[:version_text]).to eq('Version 3.4.6')
    end
  end

  describe '#version_section_title_for_context' do
    it 'returns correct title for new records' do
      expect(decorator.version_section_title_for_context).to eq('Assignment Status & Version')
    end

    it 'returns correct title for existing records' do
      assignment.save!
      expect(decorator.version_section_title_for_context).to eq('Change Type & Version')
    end
  end
end
