require 'rails_helper'

RSpec.describe Enm::AssessmentCalculatorService do
  let(:service) { Enm::AssessmentCalculatorService.new }
  
  describe '#calculate_phase_1_results' do
    it 'calculates monogamy-leaning from closed emotional and physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_openness: { emotional: -2, physical: -2 },
        active_readiness: { emotional: -2, physical: -2 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('M')
      expect(result[:readiness]).to eq('C')
    end
    
    it 'calculates swing-leaning from closed emotional, open physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_openness: { emotional: -2, physical: 2 },
        active_readiness: { emotional: -1, physical: 3 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('S')
      expect(result[:readiness]).to eq('P') # High physical, low emotional = Passive (Swing Ready)
    end
    
    it 'calculates poly-leaning from open emotional and physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_openness: { emotional: 2, physical: 2 },
        active_readiness: { emotional: 3, physical: 3 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('P')
      expect(result[:readiness]).to eq('A')
    end
    
    it 'calculates heart-leaning from open emotional, closed physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_openness: { emotional: 2, physical: -2 },
        active_readiness: { emotional: 2, physical: -1 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('H')
      expect(result[:readiness]).to eq('P')
    end
  end
  
  describe '#calculate_phase_2_results' do
    it 'calculates ECI and PCI from escalator data' do
      data = {
        emotional_escalator: [
          { comfort: 2, prior_disclosure: 1, post_disclosure: 1 },
          { comfort: 3, prior_disclosure: 2, post_disclosure: 2 },
          { comfort: 1, prior_disclosure: 0, post_disclosure: 0 }
        ],
        physical_escalator: [
          { comfort: 1, prior_disclosure: 0, post_disclosure: 0 },
          { comfort: 2, prior_disclosure: 1, post_disclosure: 1 },
          { comfort: 3, prior_disclosure: 2, post_disclosure: 2 }
        ],
        style_axes: {
          connection: 2,
          emotional_structure: -1,
          sexual_structure: 1,
          initiation_pattern: 0
        }
      }
      
      result = service.calculate_phase_2_results(data)
      
      expect(result[:eci]).to eq(2.0) # Average of 2, 3, 1
      expect(result[:pci]).to eq(2.0) # Average of 1, 2, 3
      expect(result[:style]).to eq('K') # Based on style axes
    end
  end
  
  describe '#generate_final_code' do
    it 'combines macro category, readiness, and style' do
      code = service.generate_final_code('P', 'A', 'K')
      
      expect(code).to eq('P-A-K')
    end
  end
  
  describe '#get_typology_description' do
    it 'returns description for P-A-K' do
      description = service.get_typology_description('P-A-K')
      
      expect(description[:nickname]).to eq('Polysecure Networkers')
      expect(description[:description]).to include('Emotionally interwoven lovers and friends')
    end
    
    it 'returns description for M-C-F' do
      description = service.get_typology_description('M-C-F')
      
      expect(description[:nickname]).to eq('Anchor Pair')
      expect(description[:description]).to include('Deep dyadic bond')
    end
    
    it 'returns unknown for invalid codes' do
      description = service.get_typology_description('INVALID')
      
      expect(description[:nickname]).to eq('Unknown Typology')
      expect(description[:description]).to eq('This typology combination is not recognized.')
    end
  end
end
