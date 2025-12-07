require 'rails_helper'

RSpec.describe NavigationHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  
  # Set up helper methods that are normally provided by ApplicationController
  before do
    # Capture variables for closure
    org = organization
    p = person
    t = teammate
    
    # Define helper methods directly on the helper object
    # These are normally made available via helper_method in ApplicationController
    helper.define_singleton_method(:current_organization) { org }
    helper.define_singleton_method(:current_person) { p }
    helper.define_singleton_method(:current_company_teammate) { t }
    
    # Stub policy method to return a policy double for any record
    policy_double = double(
      index?: true,
      show?: true,
      manage_employment?: true
    )
    
    helper.define_singleton_method(:policy) do |record|
      case record
      when Class
        # For class-level checks like policy(Observation).index?
        policy_double
      when Organization
        # For organization instance checks
        double(show?: true, manage_employment?: true)
      else
        # For other instance checks
        policy_double
      end
    end
  end
  
  describe '#navigation_structure' do
    it 'returns navigation structure' do
      structure = helper.navigation_structure
      
      expect(structure).to be_an(Array)
      expect(structure.length).to be > 0
    end
    
    it 'includes Dashboard' do
      structure = helper.navigation_structure
      dashboard = structure.find { |s| s[:label] == 'Dashboard' }
      
      expect(dashboard).to be_present
      expect(dashboard[:path]).to be_present
    end
    
    it 'includes Align section' do
      structure = helper.navigation_structure
      align = structure.find { |s| s[:section] == 'align' }
      
      expect(align).to be_present
      expect(align[:items]).to be_an(Array)
    end
  end
  
  describe '#nav_item_active?' do
    before do
      allow(helper).to receive(:current_page?).and_return(false)
      allow(helper).to receive(:request).and_return(double(path: '/organizations/1/employees'))
    end
    
    it 'returns false when path does not match' do
      expect(helper.nav_item_active?('/organizations/1/observations')).to eq(false)
    end
    
    it 'returns true when path matches' do
      allow(helper).to receive(:current_page?).with('/organizations/1/employees').and_return(true)
      
      expect(helper.nav_item_active?('/organizations/1/employees')).to eq(true)
    end
    
    it 'handles paths with query params' do
      allow(helper).to receive(:request).and_return(double(path: '/organizations/1/employees?page=2'))
      
      expect(helper.nav_item_active?('/organizations/1/employees')).to eq(true)
    end
  end
  
  describe '#visible_nav_items' do
    let(:items) do
      [
        {
          label: 'Test Item',
          path: '/test',
          policy_check: -> { true }
        },
        {
          label: 'Hidden Item',
          path: '/hidden',
          policy_check: -> { false }
        }
      ]
    end
    
    it 'filters items by policy check' do
      visible = helper.visible_nav_items(items)
      
      expect(visible.length).to eq(1)
      expect(visible.first[:label]).to eq('Test Item')
    end
  end
  
  describe '#visible_navigation_structure' do
    it 'returns filtered navigation structure' do
      structure = helper.visible_navigation_structure
      
      expect(structure).to be_an(Array)
      # All items should pass policy checks
      structure.each do |section|
        if section[:items]
          section[:items].each do |item|
            expect(item[:policy_check]).to be_present
          end
        end
      end
    end
  end
end

