require 'rails_helper'

RSpec.describe FlexibleNameMatcher, type: :concern do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include FlexibleNameMatcher
    end
  end
  
  let(:matcher) { test_class.new }
  let(:organization) { create(:organization) }
  
  describe '#name_variations' do
    it 'returns normalized name' do
      expect(matcher.name_variations('Test Name')).to include('Test Name')
    end
    
    it 'trims whitespace' do
      expect(matcher.name_variations('  Test Name  ')).to include('Test Name')
    end
    
    it 'includes & to and variation' do
      variations = matcher.name_variations('Test & Name')
      expect(variations).to include('Test and Name')
    end
    
    it 'includes and to & variation' do
      variations = matcher.name_variations('Test and Name')
      expect(variations).to include('Test & Name')
    end
    
    it 'includes Senior variations' do
      variations = matcher.name_variations('Sr Developer')
      expect(variations).to include('Sr Developer')
      expect(variations).to include('Sr. Developer')
      expect(variations).to include('Senior Developer')
    end
    
    it 'includes Sr. variations' do
      variations = matcher.name_variations('Sr. Developer')
      expect(variations).to include('Sr Developer')
      expect(variations).to include('Sr. Developer')
      expect(variations).to include('Senior Developer')
    end
    
    it 'includes Senior variations' do
      variations = matcher.name_variations('Senior Developer')
      expect(variations).to include('Sr Developer')
      expect(variations).to include('Sr. Developer')
      expect(variations).to include('Senior Developer')
    end
    
    it 'returns empty array for blank name' do
      expect(matcher.name_variations('')).to eq([])
      expect(matcher.name_variations(nil)).to eq([])
    end
    
    it 'removes duplicates' do
      variations = matcher.name_variations('Test Name')
      expect(variations.uniq.length).to eq(variations.length)
    end
  end
  
  describe '#find_with_flexible_matching' do
    let!(:assignment) { create(:assignment, title: 'Test & Development', company: organization) }
    
    it 'finds exact match' do
      result = matcher.find_with_flexible_matching(
        Assignment,
        :title,
        'Test & Development',
        Assignment.where(company: organization)
      )
      expect(result).to eq(assignment)
    end
    
    it 'finds with & to and variation' do
      result = matcher.find_with_flexible_matching(
        Assignment,
        :title,
        'Test and Development',
        Assignment.where(company: organization)
      )
      expect(result).to eq(assignment)
    end
    
    it 'finds with trimmed whitespace' do
      result = matcher.find_with_flexible_matching(
        Assignment,
        :title,
        '  Test & Development  ',
        Assignment.where(company: organization)
      )
      expect(result).to eq(assignment)
    end
    
    it 'returns nil when no match found' do
      result = matcher.find_with_flexible_matching(
        Assignment,
        :title,
        'Non-existent Assignment',
        Assignment.where(company: organization)
      )
      expect(result).to be_nil
    end
    
    it 'respects scope' do
      other_org = create(:organization)
      other_assignment = create(:assignment, title: 'Test & Development', company: other_org)
      
      result = matcher.find_with_flexible_matching(
        Assignment,
        :title,
        'Test & Development',
        Assignment.where(company: organization)
      )
      expect(result).to eq(assignment)
      expect(result).not_to eq(other_assignment)
    end
    
    context 'with Senior variations' do
      let!(:title) { create(:title, external_title: 'Sr Developer', company: organization) }
      
      it 'finds with Sr variation' do
        result = matcher.find_with_flexible_matching(
          Title,
          :external_title,
          'Sr Developer',
          Title.where(company_id: organization.id)
        )
        expect(result).to eq(title)
      end
      
      it 'finds with Sr. variation' do
        result = matcher.find_with_flexible_matching(
          Title,
          :external_title,
          'Sr. Developer',
          Title.where(company_id: organization.id)
        )
        expect(result).to eq(title)
      end
      
      it 'finds with Senior variation' do
        result = matcher.find_with_flexible_matching(
          Title,
          :external_title,
          'Senior Developer',
          Title.where(company_id: organization.id)
        )
        expect(result).to eq(title)
      end
    end
  end
end

