require 'rails_helper'

RSpec.describe FullNameParser do
  describe '#initialize' do
    it 'parses names immediately upon initialization' do
      parser = described_class.new('Andrew Robinson III')
      expect(parser.first_name).to eq('Andrew')
      expect(parser.last_name).to eq('Robinson')
      expect(parser.suffix).to eq('III')
    end
  end

  describe 'name parsing' do
    context 'with suffix' do
      it 'parses "Andrew Robinson III" correctly' do
        parser = described_class.new('Andrew Robinson III')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to eq('Robinson')
        expect(parser.suffix).to eq('III')
      end

      it 'parses "Andrew L. Robinson III" correctly' do
        parser = described_class.new('Andrew L. Robinson III')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to eq('L.')
        expect(parser.last_name).to eq('Robinson')
        expect(parser.suffix).to eq('III')
      end

      it 'parses "Andrew Lee Bear Robinson III" correctly' do
        parser = described_class.new('Andrew Lee Bear Robinson III')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to eq('Lee Bear')
        expect(parser.last_name).to eq('Robinson')
        expect(parser.suffix).to eq('III')
      end

      it 'parses "John Smith Jr." correctly' do
        parser = described_class.new('John Smith Jr.')
        expect(parser.first_name).to eq('John')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to eq('Smith')
        expect(parser.suffix).to eq('Jr.')
      end

      it 'parses "Dr. Jane Doe PhD" correctly' do
        parser = described_class.new('Dr. Jane Doe PhD')
        expect(parser.first_name).to eq('Dr.')
        expect(parser.middle_name).to eq('Jane')
        expect(parser.last_name).to eq('Doe')
        expect(parser.suffix).to eq('PhD')
      end
    end

    context 'without suffix' do
      it 'parses "Andrew L" correctly' do
        parser = described_class.new('Andrew L')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to eq('L')
      end

      it 'parses "Andrew" correctly' do
        parser = described_class.new('Andrew')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to be_nil
      end

      it 'parses "Andrew Robinson" correctly' do
        parser = described_class.new('Andrew Robinson')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to eq('Robinson')
      end

      it 'parses "Andrew L. Robinson" correctly' do
        parser = described_class.new('Andrew L. Robinson')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to eq('L.')
        expect(parser.last_name).to eq('Robinson')
      end

      it 'parses "Andrew Lee Bear Robinson" correctly' do
        parser = described_class.new('Andrew Lee Bear Robinson')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to eq('Lee Bear')
        expect(parser.last_name).to eq('Robinson')
      end
    end

    context 'with various middle name patterns' do
      it 'parses "Mary Jane Smith" correctly' do
        parser = described_class.new('Mary Jane Smith')
        expect(parser.first_name).to eq('Mary')
        expect(parser.middle_name).to eq('Jane')
        expect(parser.last_name).to eq('Smith')
      end

      it 'parses "Robert A. B. Johnson" correctly' do
        parser = described_class.new('Robert A. B. Johnson')
        expect(parser.first_name).to eq('Robert')
        expect(parser.middle_name).to eq('A. B.')
        expect(parser.last_name).to eq('Johnson')
      end

      it 'parses "Elizabeth Anne Marie Williams" correctly' do
        parser = described_class.new('Elizabeth Anne Marie Williams')
        expect(parser.first_name).to eq('Elizabeth')
        expect(parser.middle_name).to eq('Anne Marie')
        expect(parser.last_name).to eq('Williams')
      end
    end

    context 'edge cases' do
      it 'handles empty string' do
        parser = described_class.new('')
        expect(parser.first_name).to eq('')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to be_nil
        expect(parser.suffix).to be_nil
      end

      it 'handles nil' do
        parser = described_class.new(nil)
        expect(parser.first_name).to eq('')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to be_nil
        expect(parser.suffix).to be_nil
      end

      it 'handles single space' do
        parser = described_class.new(' ')
        expect(parser.first_name).to eq('')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to be_nil
        expect(parser.suffix).to be_nil
      end

      it 'handles multiple spaces' do
        parser = described_class.new('  Andrew   Robinson  ')
        expect(parser.first_name).to eq('Andrew')
        expect(parser.middle_name).to be_nil
        expect(parser.last_name).to eq('Robinson')
      end
    end
  end

  describe '#to_h' do
    it 'returns a hash with all name parts' do
      parser = described_class.new('Andrew L. Robinson III')
      expect(parser.to_h).to eq({
        first_name: 'Andrew',
        middle_name: 'L.',
        last_name: 'Robinson',
        suffix: 'III'
      })
    end

    it 'excludes nil values' do
      parser = described_class.new('Andrew Robinson')
      expect(parser.to_h).to eq({
        first_name: 'Andrew',
        last_name: 'Robinson'
      })
    end
  end

  describe '#to_params' do
    it 'returns the same as to_h' do
      parser = described_class.new('Andrew L. Robinson III')
      expect(parser.to_params).to eq(parser.to_h)
    end
  end

  describe 'suffix handling' do
    it 'recognizes Roman numerals' do
      %w[I II III IV V VI VII VIII IX X].each do |suffix|
        parser = described_class.new("John Smith #{suffix}")
        expect(parser.suffix).to eq(suffix)
        expect(parser.last_name).to eq('Smith')
      end
    end

    it 'recognizes professional titles' do
      %w[Jr Jr. Junior Sr Sr. Senior PhD Ph.D. MD M.D.].each do |suffix|
        parser = described_class.new("John Smith #{suffix}")
        expect(parser.suffix).to eq(suffix)
        expect(parser.last_name).to eq('Smith')
      end
    end

    it 'handles case insensitive suffixes' do
      parser = described_class.new('John Smith iii')
      expect(parser.suffix).to eq('iii')
      expect(parser.last_name).to eq('Smith')
    end
  end
end
