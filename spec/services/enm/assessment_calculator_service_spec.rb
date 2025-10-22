require 'rails_helper'

RSpec.describe Enm::AssessmentCalculatorService do
  let(:service) { Enm::AssessmentCalculatorService.new }
  
  describe '#calculate_phase_1_results' do
    it 'calculates monogamy-leaning from closed emotional and physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: -2, opposite_sex: -2 },
        passive_physical: { same_sex: -2, opposite_sex: -2 },
        active_emotional: { same_sex: -2, opposite_sex: -2 },
        active_physical: { same_sex: -2, opposite_sex: -2 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('M')
      expect(result[:readiness]).to eq('C')
    end
    
    it 'calculates swing-leaning from closed emotional, open physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: -2, opposite_sex: -2 },
        passive_physical: { same_sex: 2, opposite_sex: 2 },
        active_emotional: { same_sex: -1, opposite_sex: -1 },
        active_physical: { same_sex: 3, opposite_sex: 3 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('S')
      expect(result[:readiness]).to eq('P') # High physical, low emotional = Passive (Swing Ready)
    end
    
    it 'calculates poly-leaning from open emotional and physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: 2, opposite_sex: 2 },
        passive_physical: { same_sex: 2, opposite_sex: 2 },
        active_emotional: { same_sex: 3, opposite_sex: 3 },
        active_physical: { same_sex: 3, opposite_sex: 3 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('P')
      expect(result[:readiness]).to eq('A')
    end
    
    it 'calculates heart-leaning from open emotional, closed physical' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: 2, opposite_sex: 2 },
        passive_physical: { same_sex: -2, opposite_sex: -2 },
        active_emotional: { same_sex: 2, opposite_sex: 2 },
        active_physical: { same_sex: -1, opposite_sex: -1 }
      }
      
      result = service.calculate_phase_1_results(data)
      
      expect(result[:macro_category]).to eq('H')
      expect(result[:readiness]).to eq('P')
    end
  end
  
  describe '#calculate_phase_2_results' do
    it 'calculates ECI and PCI from escalator data' do
      data = {
        distant_steps: [
          { step: 1, comfort: { same_sex: 2, opposite_sex: 2 }, pre_disclosure: { same_sex: 'notification', opposite_sex: 'notification' }, post_disclosure: { same_sex: 'full', opposite_sex: 'full' } },
          { step: 2, comfort: { same_sex: 3, opposite_sex: 3 }, pre_disclosure: { same_sex: 'agreement', opposite_sex: 'agreement' }, post_disclosure: { same_sex: 'desired', opposite_sex: 'desired' } },
          { step: 3, comfort: { same_sex: 1, opposite_sex: 1 }, pre_disclosure: { same_sex: 'none', opposite_sex: 'none' }, post_disclosure: { same_sex: 'unwanted', opposite_sex: 'unwanted' } }
        ],
        physical_escalator: [
          { step: 4, comfort: { same_sex: 1, opposite_sex: 1 }, pre_disclosure: { same_sex: 'none', opposite_sex: 'none' }, post_disclosure: { same_sex: 'unwanted', opposite_sex: 'unwanted' } },
          { step: 5, comfort: { same_sex: 2, opposite_sex: 2 }, pre_disclosure: { same_sex: 'notification', opposite_sex: 'notification' }, post_disclosure: { same_sex: 'full', opposite_sex: 'full' } },
          { step: 6, comfort: { same_sex: 3, opposite_sex: 3 }, pre_disclosure: { same_sex: 'agreement', opposite_sex: 'agreement' }, post_disclosure: { same_sex: 'desired', opposite_sex: 'desired' } }
        ],
        emotional_escalator: [
          { step: 4, comfort: { same_sex: 2, opposite_sex: 2 }, pre_disclosure: { same_sex: 'notification', opposite_sex: 'notification' }, post_disclosure: { same_sex: 'full', opposite_sex: 'full' } },
          { step: 5, comfort: { same_sex: 3, opposite_sex: 3 }, pre_disclosure: { same_sex: 'agreement', opposite_sex: 'agreement' }, post_disclosure: { same_sex: 'desired', opposite_sex: 'desired' } },
          { step: 6, comfort: { same_sex: 1, opposite_sex: 1 }, pre_disclosure: { same_sex: 'none', opposite_sex: 'none' }, post_disclosure: { same_sex: 'unwanted', opposite_sex: 'unwanted' } }
        ]
      }
      
      result = service.calculate_phase_2_results(data)
      
      expect(result[:eci]).to eq(2.0) # Average of 2, 3, 1
      expect(result[:pci]).to eq(2.0) # Average of 1, 2, 3
      expect(result[:style]).to eq('K') # Based on escalator patterns
    end
  end
  
  describe '#partial_phase_1_analysis' do
    it 'returns analysis after Q1' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 }
      }
      
      result = service.partial_phase_1_analysis(data)
      
      expect(result[:stage]).to eq('after_q1')
      expect(result[:likely_non_monogamous]).to be true
    end
    
    it 'returns analysis after Q3' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: 2, opposite_sex: 2 },
        passive_physical: { same_sex: 2, opposite_sex: 2 }
      }
      
      result = service.partial_phase_1_analysis(data)
      
      expect(result[:stage]).to eq('after_q3')
      expect(result[:likely_poly]).to be true
    end
    
    it 'returns analysis after Q5' do
      data = {
        core_openness: { same_sex: 2, opposite_sex: 2 },
        passive_emotional: { same_sex: 2, opposite_sex: 2 },
        passive_physical: { same_sex: 2, opposite_sex: 2 },
        active_emotional: { same_sex: 3, opposite_sex: 3 },
        active_physical: { same_sex: 3, opposite_sex: 3 }
      }
      
      result = service.partial_phase_1_analysis(data)
      
      expect(result[:stage]).to eq('after_q5')
      expect(result[:readiness]).to eq('A')
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
