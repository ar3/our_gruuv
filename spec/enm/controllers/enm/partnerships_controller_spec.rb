require_relative '../../spec_helper'

RSpec.describe Enm::PartnershipsController, type: :controller do
  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end
  
  describe 'POST #create' do
    let(:assessment1) { create(:enm_assessment, :poly_leaning) }
    let(:assessment2) { create(:enm_assessment, :swing_leaning) }
    
    context 'with valid assessment codes' do
      it 'creates a new partnership' do
        expect {
      post :create, params: {
        enm_partnership: {
          assessment_codes: "#{assessment1.code}, #{assessment2.code}"
        }
      }
        }.to change(EnmPartnership, :count).by(1)
        
        partnership = EnmPartnership.last
        expect(partnership.assessment_codes).to include(assessment1.code, assessment2.code)
        expect(response).to redirect_to(enm_partnership_path(partnership.code))
      end
    end
    
    context 'with invalid data' do
      it 'renders new with errors' do
        post :create, params: { 
          enm_partnership: { 
            assessment_codes: "" 
          } 
        }
        
        expect(response).to render_template(:new)
      end
    end
  end
  
  describe 'GET #show' do
    let(:partnership) { create(:enm_partnership, :hybrid) }
    
    it 'returns success' do
      get :show, params: { code: partnership.code }
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the show template' do
      get :show, params: { code: partnership.code }
      expect(response).to render_template(:show)
    end
    
    it 'assigns the partnership' do
      get :show, params: { code: partnership.code }
      expect(assigns(:partnership)).to eq(partnership)
    end
  end
  
  describe 'POST #add_assessment' do
    let(:partnership) { create(:enm_partnership) }
    let(:new_assessment) { create(:enm_assessment) }
    
    it 'adds the assessment to the partnership' do
      post :add_assessment, params: { 
        code: partnership.code, 
        assessment_code: new_assessment.code 
      }
      
      partnership.reload
      expect(partnership.assessment_codes).to include(new_assessment.code)
      expect(response).to redirect_to(enm_partnership_path(partnership.code))
    end
  end
  
  describe 'DELETE #remove_assessment' do
    let(:assessment1) { create(:enm_assessment) }
    let(:assessment2) { create(:enm_assessment) }
    let(:partnership) { create(:enm_partnership, assessment_codes: [assessment1.code, assessment2.code]) }
    
    it 'removes the assessment from the partnership' do
      delete :remove_assessment, params: { 
        code: partnership.code, 
        assessment_code: assessment1.code 
      }
      
      partnership.reload
      expect(partnership.assessment_codes).not_to include(assessment1.code)
      expect(partnership.assessment_codes).to include(assessment2.code)
      expect(response).to redirect_to(enm_partnership_path(partnership.code))
    end
  end
end
