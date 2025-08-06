require 'rails_helper'

RSpec.describe PositionTypesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:position_major_level) { create(:position_major_level) }
  let(:position_type) { create(:position_type, organization: organization, position_major_level: position_major_level) }
  let(:person) { create(:person, current_organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:source_position) { create(:position, position_type: position_type, position_level: position_level) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
  end

  describe 'POST #clone_positions' do
    context 'when position_type is found' do
      before do
        source_position # Create the source position
      end

      it 'does not redirect to nil' do
        expect {
          post :clone_positions, params: { 
            id: position_type.id, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.not_to raise_error(ActionController::ActionControllerError, /Cannot redirect to nil/)
      end

      it 'redirects to position_type with success message when positions are created' do
        # Create a different position level for the target
        target_level = create(:position_level, position_major_level: position_major_level)
        
        post :clone_positions, params: { 
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(position_type)
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'redirects to position_type with alert when no positions are created' do
        # Create a different position level and a position that already exists for it
        target_level = create(:position_level, position_major_level: position_major_level)
        create(:position, position_type: position_type, position_level: target_level)
        
        post :clone_positions, params: { 
          id: position_type.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(position_type)
        expect(flash[:alert]).to include('No new positions were created')
      end
    end

    context 'when position_type is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          post :clone_positions, params: { 
            id: 999999, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end 