require 'rails_helper'

RSpec.describe DecoratorSemanticVersionable, type: :decorator do
  # Create a test decorator that includes the concern
  let(:test_model) { build(:aspiration, semantic_version: '1.2.3') }
  let(:test_decorator_class) do
    Class.new(SimpleDelegator) do
      include DecoratorSemanticVersionable
    end
  end
  let(:decorator) { test_decorator_class.new(test_model) }

  describe '#new_version_options' do
    it 'returns array with three options' do
      options = decorator.new_version_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(3)
    end

    it 'includes ready option with correct version' do
      options = decorator.new_version_options
      ready = options.find { |o| o[:value] == 'ready' }
      expect(ready[:version_text]).to eq('Version 1.0.0')
    end
  end

  describe '#edit_version_options' do
    before { test_model.save! }

    it 'returns array with three options' do
      options = decorator.edit_version_options
      expect(options).to be_an(Array)
      expect(options.length).to eq(3)
    end

    it 'calculates versions correctly based on current version' do
      options = decorator.edit_version_options
      fundamental = options.find { |o| o[:value] == 'fundamental' }
      clarifying = options.find { |o| o[:value] == 'clarifying' }
      insignificant = options.find { |o| o[:value] == 'insignificant' }
      
      expect(fundamental[:version_text]).to eq('Version 2.0.0')
      expect(clarifying[:version_text]).to eq('Version 1.3.0')
      expect(insignificant[:version_text]).to eq('Version 1.2.4')
    end
  end

  describe '#version_section_title_for_context' do
    it 'returns correct title for new records' do
      expect(decorator.version_section_title_for_context('Test')).to eq('Test Status & Version')
    end

    it 'returns correct title for existing records' do
      test_model.save!
      expect(decorator.version_section_title_for_context('Test')).to eq('Change Type & Version')
    end
  end

  describe '#version_section_description_for_context' do
    it 'returns correct description for new records' do
      description = decorator.version_section_description_for_context('Test')
      expect(description).to include('readiness level')
    end

    it 'returns correct description for existing records' do
      test_model.save!
      description = decorator.version_section_description_for_context('Test')
      expect(description).to include('Current version: 1.2.3')
    end
  end
end

