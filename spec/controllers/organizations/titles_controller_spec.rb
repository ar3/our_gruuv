require 'rails_helper'

RSpec.describe Organizations::TitlesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }
  let(:person) { create(:person) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:source_position) { create(:position, title: title, position_level: position_level) }

  before do
    teammate = sign_in_as_teammate(person, organization)
    teammate.update(can_manage_maap: true)
  end

  describe 'GET #index' do
    it 'authorizes the organization for view_titles?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :view_titles?)
      get :index, params: { organization_id: organization.id }
    end
  end

  describe 'GET #new' do
    it 'authorizes the organization for manage_maap?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :manage_maap?)
      get :new, params: { organization_id: organization.id }
    end
  end

  describe 'POST #create' do
    it 'authorizes the organization for manage_maap?' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(anything, :manage_maap?)
      post :create, params: { 
        organization_id: organization.id,
        title: {
          position_major_level_id: position_major_level.id,
          external_title: 'Test Position Type'
        }
      }
    end

    it 'uses TitleSaveService to create' do
      allow(TitleSaveService).to receive(:create) do |args|
        # Simulate what the service does - modify the title
        args[:title].assign_attributes(args[:params]) if args[:params]
        args[:title].save!
        Result.ok(args[:title])
      end
      
      post :create, params: { 
        organization_id: organization.id,
        title: {
          position_major_level_id: position_major_level.id,
          external_title: 'Test Position Type'
        }
      }
      
      expect(TitleSaveService).to have_received(:create)
    end

    it 'creates a position type successfully' do
      expect {
        post :create, params: { 
          organization_id: organization.id,
          title: {
            position_major_level_id: position_major_level.id,
            external_title: 'New Position Type'
          }
        }
      }.to change(Title, :count).by(1)
      
      expect(response).to redirect_to(organization_title_path(organization, Title.last))
      expect(flash[:notice]).to eq('Title was successfully created.')
    end

    it 'renders new with errors when creation fails' do
      post :create, params: { 
        organization_id: organization.id,
        title: {
          position_major_level_id: position_major_level.id,
          external_title: '' # Invalid
        }
      }
      
      expect(response).to render_template(:new)
      expect(response.status).to eq(422)
    end
  end

  describe 'PATCH #update' do
    it 'authorizes the title' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(title)
      patch :update, params: { 
        organization_id: organization.id,
        id: title.id,
        title: {
          external_title: 'Updated Title'
        }
      }
    end

    it 'uses TitleSaveService to update' do
      allow(TitleSaveService).to receive(:update).and_return(Result.ok(title))
      
      patch :update, params: { 
        organization_id: organization.id,
        id: title.id,
        title: {
          external_title: 'Updated Title'
        }
      }
      
      expect(TitleSaveService).to have_received(:update)
    end

    it 'updates a position type successfully' do
      patch :update, params: { 
        organization_id: organization.id,
        id: title.id,
        title: {
          external_title: 'Updated Title'
        }
      }
      
      expect(title.reload.external_title).to eq('Updated Title')
      expect(response).to redirect_to(organization_title_path(organization, title))
      expect(flash[:notice]).to eq('Title was successfully updated.')
    end

    it 'updates position levels when major level changes' do
      new_major_level = create(:position_major_level, major_level: 2, set_name: 'Engineering')
      position1 = create(:position, title: title, position_level: position_level)
      original_level_value = position_level.level # e.g., "1.1"
      minor_level = original_level_value.split('.').last # e.g., "1"
      expected_new_level = "#{new_major_level.major_level}.#{minor_level}" # e.g., "2.1"
      
      patch :update, params: { 
        organization_id: organization.id,
        id: title.id,
        title: {
          position_major_level_id: new_major_level.id
        }
      }
      
      expect(title.reload.position_major_level_id).to eq(new_major_level.id)
      new_position_level = PositionLevel.find_by(position_major_level: new_major_level, level: expected_new_level)
      expect(new_position_level).to be_present
      expect(position1.reload.position_level).to eq(new_position_level)
      expect(position1.reload.position_level.level).to eq(expected_new_level)
    end

    it 'renders edit with errors when update fails' do
      patch :update, params: { 
        organization_id: organization.id,
        id: title.id,
        title: {
          external_title: '' # Invalid
        }
      }
      
      expect(response).to render_template(:edit)
      expect(response.status).to eq(422)
    end
  end

  describe 'DELETE #destroy' do
    it 'authorizes the title' do
      allow(controller).to receive(:authorize).and_call_original
      expect(controller).to receive(:authorize).with(title)
      delete :destroy, params: { 
        organization_id: organization.id,
        id: title.id
      }
    end

    it 'uses TitleSaveService to delete' do
      allow(TitleSaveService).to receive(:delete).and_return(Result.ok(title))
      allow(title).to receive(:destroy).and_return(true)
      
      delete :destroy, params: { 
        organization_id: organization.id,
        id: title.id
      }
      
      expect(TitleSaveService).to have_received(:delete)
    end

    it 'deletes a position type successfully' do
      title_id = title.id
      
      expect {
        delete :destroy, params: { 
          organization_id: organization.id,
          id: title.id
        }
      }.to change(Title, :count).by(-1)
      
      expect(Title.find_by(id: title_id)).to be_nil
      expect(response).to redirect_to(organization_positions_path(organization))
      expect(flash[:notice]).to eq('Title was successfully deleted.')
    end

    it 'redirects with alert when deletion fails' do
      allow(TitleSaveService).to receive(:delete).and_return(Result.err('Deletion failed'))
      
      delete :destroy, params: { 
        organization_id: organization.id,
        id: title.id
      }
      
      expect(response).to redirect_to(organization_positions_path(organization))
      expect(flash[:alert]).to eq('Deletion failed')
    end
  end

  describe 'POST #clone_positions' do
    context 'when title is found' do
      before do
        source_position # Create the source position
      end

      it 'authorizes the title with clone_positions? action' do
        allow(controller).to receive(:authorize).and_call_original
        expect(controller).to receive(:authorize).with(title, :clone_positions?)
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: title.id, 
          source_position_id: source_position.id, 
          target_level_ids: [position_level.id] 
        }
      end

      it 'successfully clones positions without errors' do
        expect {
          post :clone_positions, params: { 
            organization_id: organization.id,
            id: title.id, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.not_to raise_error
      end

      it 'redirects to organization_title_path with success message when positions are created' do
        # Create a different position level for the target
        target_level = create(:position_level, position_major_level: position_major_level)
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: title.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(organization_title_path(organization, title))
        expect(flash[:notice]).to include('Successfully created')
      end

      it 'redirects to organization_title_path with alert when no positions are created' do
        # Create a different position level and a position that already exists for it
        target_level = create(:position_level, position_major_level: position_major_level)
        create(:position, title: title, position_level: target_level)
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: title.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        expect(response).to redirect_to(organization_title_path(organization, title))
        expect(flash[:alert]).to include('No new positions were created')
      end

      it 'clones position assignments with min, max, and type attributes' do
        # Create a different position level for the target
        target_level = create(:position_level, position_major_level: position_major_level)
        
        # Create source position assignments with min, max, and type
        assignment1 = create(:assignment)
        assignment2 = create(:assignment)
        
        source_pa1 = create(:position_assignment,
          position: source_position,
          assignment: assignment1,
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 40
        )
        source_pa2 = create(:position_assignment,
          position: source_position,
          assignment: assignment2,
          assignment_type: 'suggested',
          min_estimated_energy: 10,
          max_estimated_energy: 30
        )
        
        post :clone_positions, params: { 
          organization_id: organization.id,
          id: title.id, 
          source_position_id: source_position.id, 
          target_level_ids: [target_level.id] 
        }
        
        # Find the cloned position
        cloned_position = Position.find_by(title: title, position_level: target_level)
        expect(cloned_position).to be_present
        
        # Verify the cloned position assignments
        cloned_assignments = cloned_position.position_assignments.order(:id)
        expect(cloned_assignments.count).to eq(2)
        
        # Verify first assignment
        cloned_pa1 = cloned_assignments.find_by(assignment: assignment1)
        expect(cloned_pa1).to be_present
        expect(cloned_pa1.assignment_type).to eq('required')
        expect(cloned_pa1.min_estimated_energy).to eq(20)
        expect(cloned_pa1.max_estimated_energy).to eq(40)
        
        # Verify second assignment
        cloned_pa2 = cloned_assignments.find_by(assignment: assignment2)
        expect(cloned_pa2).to be_present
        expect(cloned_pa2.assignment_type).to eq('suggested')
        expect(cloned_pa2.min_estimated_energy).to eq(10)
        expect(cloned_pa2.max_estimated_energy).to eq(30)
      end
    end

    context 'when title is not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          post :clone_positions, params: { 
            organization_id: organization.id,
            id: 999999, 
            source_position_id: source_position.id, 
            target_level_ids: [position_level.id] 
          }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET #show' do
    let(:position) { create(:position, title: title, position_level: position_level) }
    let(:employee_person) { create(:person) }
    let(:employee_teammate) { create(:teammate, person: employee_person, organization: organization) }

    it 'loads teammates with active employment tenures on positions with this position type' do
      tenure = build(:employment_tenure, 
        teammate: employee_teammate, 
        company: organization, 
        ended_at: nil
      )
      tenure.position = position
      tenure.save!

      get :show, params: { organization_id: organization.id, id: title.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:teammates_with_title)).to be_present
      expect(assigns(:teammates_with_title).count).to eq(1)
      expect(assigns(:teammates_with_title).first.teammate.id).to eq(employee_teammate.id)
    end

    it 'orders teammates by last name, first name' do
      employee_person2 = create(:person, first_name: 'Alice', last_name: 'Zebra')
      employee_teammate2 = create(:teammate, person: employee_person2, organization: organization)
      position2 = create(:position, title: title, position_level: create(:position_level, position_major_level: title.position_major_level))
      
      tenure1 = build(:employment_tenure, 
        teammate: employee_teammate, 
        company: organization, 
        ended_at: nil
      )
      tenure1.position = position
      tenure1.save!
      
      tenure2 = build(:employment_tenure, 
        teammate: employee_teammate2, 
        company: organization, 
        ended_at: nil
      )
      tenure2.position = position2
      tenure2.save!

      get :show, params: { organization_id: organization.id, id: title.id }
      
      teammates = assigns(:teammates_with_title)
      expect(teammates.count).to eq(2)
      # Should be ordered by last name
      expect(teammates.first.teammate.person.last_name).to be < teammates.last.teammate.person.last_name
    end

    it 'only includes active employment tenures' do
      inactive_employee_person = create(:person)
      inactive_employee_teammate = create(:teammate, person: inactive_employee_person, organization: organization)
      inactive_tenure = build(:employment_tenure, 
        teammate: inactive_employee_teammate, 
        company: organization, 
        ended_at: 1.day.ago
      )
      inactive_tenure.position = position
      inactive_tenure.save!

      get :show, params: { organization_id: organization.id, id: title.id }
      
      teammates = assigns(:teammates_with_title)
      expect(teammates).to be_empty
    end

    it 'only includes teammates with positions of this position type' do
      other_title = create(:title, organization: organization)
      other_position = create(:position, title: other_title, position_level: create(:position_level, position_major_level: other_title.position_major_level))
      other_employee_person = create(:person)
      other_employee_teammate = create(:teammate, person: other_employee_person, organization: organization)
      
      tenure1 = build(:employment_tenure, 
        teammate: employee_teammate, 
        company: organization, 
        ended_at: nil
      )
      tenure1.position = position
      tenure1.save!
      
      tenure2 = build(:employment_tenure, 
        teammate: other_employee_teammate, 
        company: organization, 
        ended_at: nil
      )
      tenure2.position = other_position
      tenure2.save!

      get :show, params: { organization_id: organization.id, id: title.id }
      
      teammates = assigns(:teammates_with_title)
      expect(teammates.count).to eq(1)
      expect(teammates.first.teammate.id).to eq(employee_teammate.id)
    end

    it 'returns empty array when no teammates have this position type' do
      get :show, params: { organization_id: organization.id, id: title.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:teammates_with_title)).to be_empty
    end
  end
end

