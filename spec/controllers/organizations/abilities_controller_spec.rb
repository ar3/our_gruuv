require 'rails_helper'

RSpec.describe Organizations::AbilitiesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }

  before do
    # Create a teammate for the person in the organization with MAAP management permissions
    create(:teammate, person: person, organization: organization, can_manage_maap: true)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #new' do
    it 'renders the new ability form without NoMethodError' do
      expect {
        get :new, params: { organization_id: organization.id }
      }.not_to raise_error(NoMethodError)
      
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :new, params: { organization_id: organization.id }
      
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:form)).to be_present
      expect(assigns(:form)).to be_a(AbilityForm)
      expect(assigns(:form).model).to be_a(Ability)
    end

    it 'renders the new template' do
      get :new, params: { organization_id: organization.id }
      expect(response).to render_template(:new)
    end

    it 'does not call company_abilities_path' do
      # This test ensures the error is fixed
      expect(Rails.application.routes.url_helpers).not_to respond_to(:company_abilities_path)
    end
  end

  describe 'POST #create' do
    before do
      # Temporarily disable PaperTrail for this test to avoid controller_info issues
      PaperTrail.enabled = false
    end

    after do
      # Re-enable PaperTrail after the test
      PaperTrail.enabled = true
    end

    describe 'PaperTrail integration' do
      before do
        # Enable PaperTrail for this specific test
        PaperTrail.enabled = true
      end

      after do
        # Disable PaperTrail after the test
        PaperTrail.enabled = false
      end

      it 'handles PaperTrail current_person_id error gracefully' do
        expect {
          post :create, params: { 
            organization_id: organization.id, 
            ability: {
              name: 'Test Ability',
              description: 'A test ability',
              organization_id: organization.id,
              milestone_1_description: 'Basic understanding',
              version_type: 'ready'
            }
          }
        }.not_to raise_error(ActiveModel::UnknownAttributeError)
      end

      it 'stores PaperTrail controller info in meta column' do
        post :create, params: { 
          organization_id: organization.id, 
          ability: {
            name: 'Test Ability',
            description: 'A test ability',
            organization_id: organization.id,
            milestone_1_description: 'Basic understanding',
            version_type: 'ready'
          }
        }

        expect(response).to have_http_status(:redirect)
        
        ability = Ability.last
        versions = PaperTrail::Version.where(item: ability)
        version = versions.first
        
        expect(version.meta).to be_present
        teammate = person.teammates.find_by(organization: organization)
        expect(version.meta['current_teammate_id']).to eq(teammate.id)
      end
    end

    let(:valid_attributes) do
      {
        name: 'Test Ability',
        description: 'A test ability',
        organization_id: organization.id,
        milestone_1_description: 'Basic understanding',
        milestone_2_description: 'Intermediate skills',
        milestone_3_description: 'Advanced proficiency',
        milestone_4_description: 'Expert level',
        milestone_5_description: 'Master level',
        version_type: 'ready'
      }
    end

    it 'creates a new ability ready for use' do
      expect {
        post :create, params: { organization_id: organization.id, ability: valid_attributes }
      }.to change(Ability, :count).by(1)
      
      ability = Ability.last
      expect(ability.semantic_version).to eq("1.0.0")
      expect(ability.name).to eq('Test Ability')
      expect(ability.milestone_1_description).to eq('Basic understanding')
    end

    it 'creates a new ability nearly ready' do
      attributes = valid_attributes.merge(version_type: 'nearly_ready')
      expect {
        post :create, params: { organization_id: organization.id, ability: attributes }
      }.to change(Ability, :count).by(1)
      
      ability = Ability.last
      expect(ability.semantic_version).to eq("0.1.0")
    end

    it 'creates a new ability as early draft' do
      attributes = valid_attributes.merge(version_type: 'early_draft')
      expect {
        post :create, params: { organization_id: organization.id, ability: attributes }
      }.to change(Ability, :count).by(1)
      
      ability = Ability.last
      expect(ability.semantic_version).to eq("0.0.1")
    end

    it 'redirects to the created ability' do
      post :create, params: { organization_id: organization.id, ability: valid_attributes }
      expect(response).to redirect_to(organization_ability_path(organization, Ability.last))
    end

    it 'shows validation error when version_type is not selected' do
      attributes_without_version = valid_attributes.except(:version_type)
      post :create, params: { organization_id: organization.id, ability: attributes_without_version }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(assigns(:form).errors[:version_type]).to include("can't be blank")
    end

    it 'handles form submission with proper parameter structure' do
      # Test that the form sends parameters in the expected format
      post :create, params: { 
        organization_id: organization.id, 
        ability: {
          name: 'Test Ability',
          description: 'Test Description',
          organization_id: organization.id,
          version_type: 'ready',
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills',
          milestone_3_description: 'Advanced proficiency',
          milestone_4_description: 'Expert level',
          milestone_5_description: 'Master level'
        }
      }
      
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_ability_path(organization, Ability.last))
    end

    it 'handles empty form submission gracefully' do
      # Test what happens when form is submitted with no data
      post :create, params: { organization_id: organization.id }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(assigns(:form).errors[:base]).to include("Form data is missing. Please fill out the form and try again.")
    end

    it 'handles form submission with missing ability parameter' do
      # Test what happens when ability parameter is missing
      post :create, params: { 
        organization_id: organization.id,
        some_other_param: 'value'
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      expect(assigns(:form).errors[:base]).to include("Form data is missing. Please fill out the form and try again.")
    end

    it 'preserves form data when validation fails' do
      # Test that form data is preserved when validation fails
      post :create, params: { 
        organization_id: organization.id,
        ability: {
          name: 'Test Ability', # Valid name
          description: '', # Invalid: empty description
          organization_id: organization.id,
          version_type: 'ready',
          milestone_1_description: 'Basic understanding'
          # Missing other milestone descriptions
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      
      # Form should preserve the submitted data
      form = assigns(:form)
      expect(form.name).to eq('Test Ability')
      expect(form.description).to eq('')
      expect(form.organization_id).to eq(organization.id.to_s)
      expect(form.version_type).to eq('ready')
      expect(form.milestone_1_description).to eq('Basic understanding')
    end

    it 'shows specific validation errors instead of generic ones' do
      # Test that specific validation errors are shown
      post :create, params: { 
        organization_id: organization.id,
        ability: {
          name: '', # Invalid: empty name
          description: '', # Invalid: empty description
          organization_id: organization.id,
          version_type: 'ready'
          # Missing milestone descriptions
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      
      # Should show specific validation errors, not generic ones
      form = assigns(:form)
      expect(form.errors[:name]).to include("can't be blank")
      expect(form.errors[:description]).to include("can't be blank")
      expect(form.errors[:milestone_descriptions]).to include("At least one milestone description is required")
      
      # Should NOT have generic base errors for validation failures
      expect(form.errors[:base]).to be_empty
    end

    it 'shows specific error for missing version type' do
      # Test specific error for missing version type
      post :create, params: { 
        organization_id: organization.id,
        ability: {
          name: 'Test Ability',
          description: 'Test Description',
          organization_id: organization.id,
          milestone_1_description: 'Basic understanding'
          # Missing version_type
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
      
      form = assigns(:form)
      expect(form.errors[:version_type]).to include("can't be blank")
      expect(form.errors[:base]).to be_empty
    end
  end

  describe 'PATCH #update' do
    before do
      # Temporarily disable PaperTrail for this test to avoid controller_info issues
      PaperTrail.enabled = false
    end

    after do
      # Re-enable PaperTrail after the test
      PaperTrail.enabled = true
    end

    let!(:existing_ability) { 
      create(:ability, 
        organization: organization, 
        semantic_version: "1.0.0",
        milestone_1_description: 'Basic understanding',
        milestone_2_description: 'Intermediate skills'
      ) 
    }

    it 'updates ability with fundamental change' do
      patch :update, params: { 
        organization_id: organization.id, 
        id: existing_ability.id, 
        ability: { 
          name: 'Updated Ability', 
          description: 'Updated Description',
          organization_id: organization.id,
          version_type: 'fundamental',
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills'
        }
      }
      
      existing_ability.reload
      expect(existing_ability.semantic_version).to eq("2.0.0")
      expect(existing_ability.name).to eq('Updated Ability')
    end

    it 'updates ability with clarifying change' do
      patch :update, params: { 
        organization_id: organization.id, 
        id: existing_ability.id, 
        ability: { 
          name: 'Updated Ability', 
          description: 'Updated Description',
          organization_id: organization.id,
          version_type: 'clarifying',
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills'
        }
      }
      
      existing_ability.reload
      expect(existing_ability.semantic_version).to eq("1.1.0")
    end

    it 'updates ability with insignificant change' do
      patch :update, params: { 
        organization_id: organization.id, 
        id: existing_ability.id, 
        ability: { 
          name: 'Updated Ability', 
          description: 'Updated Description',
          organization_id: organization.id,
          version_type: 'insignificant',
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills'
        }
      }
      
      existing_ability.reload
      expect(existing_ability.semantic_version).to eq("1.0.1")
    end

    it 'shows validation error when version_type is not selected for update' do
      patch :update, params: { 
        organization_id: organization.id, 
        id: existing_ability.id, 
        ability: { 
          name: 'Updated Ability', 
          description: 'Updated Description',
          organization_id: organization.id,
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills'
          # No version_type
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      expect(assigns(:form).errors[:version_type]).to include("can't be blank")
    end

    it 'sets up ability_decorator when validation fails and renders edit template' do
      # This test ensures that @ability_decorator is available when update fails validation
      # and renders the edit template, preventing NoMethodError
      patch :update, params: { 
        organization_id: organization.id, 
        id: existing_ability.id, 
        ability: { 
          name: '', # Invalid: empty name to trigger validation failure
          description: 'Updated Description',
          organization_id: organization.id,
          version_type: 'clarifying',
          milestone_1_description: 'Basic understanding',
          milestone_2_description: 'Intermediate skills'
        }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:edit)
      
      # Ensure @ability_decorator is set up properly
      expect(assigns(:ability_decorator)).to be_present
      expect(assigns(:ability_decorator)).to be_a(AbilityDecorator)
      expect(assigns(:ability_decorator).id).to eq(existing_ability.id)
      
      # Ensure the decorator methods are available (this would fail with NoMethodError if not set up)
      expect { assigns(:ability_decorator).version_section_title_for_context }.not_to raise_error
      expect { assigns(:ability_decorator).version_section_description_for_context }.not_to raise_error
      expect { assigns(:ability_decorator).edit_version_options }.not_to raise_error
    end
  end
end
