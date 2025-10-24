require_relative '../../spec_helper'

RSpec.describe Enm::AssessmentsController, type: :controller do
  describe 'GET #new' do
    it 'creates a new assessment and redirects to phase 1' do
      expect {
        get :new
      }.to change(EnmAssessment, :count).by(1)
      
      assessment = EnmAssessment.last
      expect(response).to redirect_to(phase_enm_assessment_path(assessment.code, phase: 1))
    end
  end
  
  describe 'GET #show' do
    let(:assessment) { create(:enm_assessment, :poly_leaning) }
    
    it 'returns success' do
      get :show, params: { code: assessment.code }
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the show template' do
      get :show, params: { code: assessment.code }
      expect(response).to render_template(:show)
    end
    
    it 'assigns the assessment' do
      get :show, params: { code: assessment.code }
      expect(assigns(:assessment)).to eq(assessment)
    end
  end
  
  describe 'GET #show_phase' do
    let(:assessment) { create(:enm_assessment, :incomplete) }
    
    it 'returns success for phase 1' do
      get :show_phase, params: { code: assessment.code, phase: 1 }
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the show_phase template' do
      get :show_phase, params: { code: assessment.code, phase: 1 }
      expect(response).to render_template(:show_phase)
    end
    
    it 'assigns the assessment' do
      get :show_phase, params: { code: assessment.code, phase: 1 }
      expect(assigns(:assessment)).to eq(assessment)
    end
  end
  
  describe 'PATCH #update_phase' do
    let(:assessment) { create(:enm_assessment, :incomplete) }
    
    context 'with valid phase 1 data' do
      let(:phase_1_data) do
        {
          core_openness_same_sex: 2,
          core_openness_opposite_sex: 2,
          passive_openness_emotional: 2,
          passive_openness_physical: 2,
          active_readiness_emotional: 3,
          active_readiness_physical: 3
        }
      end
      
      it 'updates the assessment and redirects to phase 2' do
        patch :update_phase, params: { 
          code: assessment.code, 
          phase: 1, 
          assessment: phase_1_data 
        }
        
        assessment.reload
        expect(assessment.completed_phase).to eq(1)
        expect(assessment.macro_category).to eq('P')
        expect(response).to redirect_to(phase_enm_assessment_path(assessment.code, phase: 2))
      end
    end
    
    context 'with invalid data' do
      it 'renders show_phase with errors' do
        patch :update_phase, params: { 
          code: assessment.code, 
          phase: 1, 
          assessment: { core_openness: {} } 
        }
        
        expect(response).to render_template(:show_phase)
      end
    end
  end
  
  describe 'GET #edit' do
    let(:assessment) { create(:enm_assessment, :poly_leaning) }
    
    it 'returns success' do
      get :edit, params: { code: assessment.code }
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the edit template' do
      get :edit, params: { code: assessment.code }
      expect(response).to render_template(:edit)
    end
  end
end
