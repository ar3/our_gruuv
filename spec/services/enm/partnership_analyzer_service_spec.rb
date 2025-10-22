require 'rails_helper'

RSpec.describe Enm::PartnershipAnalyzerService do
  let(:service) { Enm::PartnershipAnalyzerService.new }
  
  describe '#analyze_compatibility' do
    it 'analyzes compatibility between two assessments' do
      assessment_codes = ['ABC12345', 'DEF67890']
      
      # Mock assessments
      assessment1 = double('assessment', macro_category: 'P', readiness: 'A', style: 'K')
      assessment2 = double('assessment', macro_category: 'S', readiness: 'P', style: 'H')
      
      allow(EnmAssessment).to receive(:where).with(code: assessment_codes).and_return([assessment1, assessment2])
      
      result = service.analyze_compatibility(assessment_codes)
      
      expect(result[:relationship_type]).to eq('H') # Hybrid
      expect(result[:compatibility_score]).to be_present
      expect(result[:divergences]).to be_present
    end
    
    it 'handles single assessment' do
      assessment_codes = ['ABC12345']
      
      assessment = double('assessment', macro_category: 'P', readiness: 'A', style: 'K')
      allow(EnmAssessment).to receive(:where).with(code: assessment_codes).and_return([assessment])
      
      result = service.analyze_compatibility(assessment_codes)
      
      expect(result[:relationship_type]).to eq('P')
      expect(result[:compatibility_score]).to eq(100) # Perfect compatibility with self
    end
  end
  
  describe '#determine_relationship_type' do
    it 'determines Hybrid for Poly + Swing' do
      assessments = [
        double('assessment', macro_category: 'P'),
        double('assessment', macro_category: 'S')
      ]
      
      result = service.determine_relationship_type(assessments)
      expect(result).to eq('H')
    end
    
    it 'determines Polysecure for Poly + Poly' do
      assessments = [
        double('assessment', macro_category: 'P'),
        double('assessment', macro_category: 'P')
      ]
      
      result = service.determine_relationship_type(assessments)
      expect(result).to eq('P')
    end
    
    it 'determines Monogamy for Monogamy + Monogamy' do
      assessments = [
        double('assessment', macro_category: 'M'),
        double('assessment', macro_category: 'M')
      ]
      
      result = service.determine_relationship_type(assessments)
      expect(result).to eq('M')
    end
  end
  
  describe '#identify_divergences' do
    it 'identifies where partners differ most' do
      assessments = [
        double('assessment', macro_category: 'P', readiness: 'A', style: 'K'),
        double('assessment', macro_category: 'S', readiness: 'P', style: 'H')
      ]
      
      divergences = service.identify_divergences(assessments)
      
      expect(divergences).to include(:macro_category)
      expect(divergences).to include(:readiness)
      expect(divergences).to include(:style)
    end
  end
  
  describe '#generate_conversation_starters' do
    it 'generates relevant conversation starters' do
      assessments = [
        double('assessment', macro_category: 'P', readiness: 'A', style: 'K'),
        double('assessment', macro_category: 'S', readiness: 'P', style: 'H')
      ]
      
      starters = service.generate_conversation_starters(assessments)
      
      expect(starters).to be_an(Array)
      expect(starters.length).to be > 0
      expect(starters.first).to be_a(String)
    end
  end
end




