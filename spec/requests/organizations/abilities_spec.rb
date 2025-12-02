require 'rails_helper'

RSpec.describe 'Organizations::Abilities', type: :request do
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: true) }

  before do
    teammate # Ensure teammate is created with can_manage_maap: true
    sign_in_as_teammate_for_request(person, organization)
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'POST /organizations/:organization_id/abilities' do
    context 'when form is submitted with valid data' do
      it 'creates the ability successfully' do
        post organization_abilities_path(organization), params: {
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

        if response.status != 302
          puts "Response status: #{response.status}"
          puts "Response body: #{response.body}"
        end

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_ability_path(organization, Ability.last))
        expect(Ability.last.name).to eq('Test Ability')
        expect(Ability.last.semantic_version).to eq('1.0.0')
      end
    end

    context 'when form is submitted with no data' do
      it 'shows validation errors and renders new template' do
        post organization_abilities_path(organization), params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(response.body).to include('Form data is missing')
      end
    end

    context 'when form is submitted with missing ability parameter' do
      it 'shows validation errors and renders new template' do
        post organization_abilities_path(organization), params: {
          some_other_param: 'value'
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(response.body).to include('Form data is missing')
      end
    end

    context 'when form is submitted with invalid data' do
      it 'shows validation errors and renders new template' do
        post organization_abilities_path(organization), params: {
          ability: {
            name: '', # Invalid: empty name
            description: 'Test Description',
            organization_id: organization.id,
            version_type: 'ready'
            # Missing milestone descriptions
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
        expect(response.body).to include('Name can&#39;t be blank')
        expect(response.body).to include('At least one milestone description is required')
      end

      it 'preserves form data when validation fails' do
        post organization_abilities_path(organization), params: {
          ability: {
            name: 'Test Ability',
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
        expect(response.body).to include('value="Test Ability"')
        expect(response.body).to include('Basic understanding')
        expect(response.body).to include('Description can&#39;t be blank')
      end

      it 'shows specific field errors instead of generic ones' do
        post organization_abilities_path(organization), params: {
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
        
      # Should show specific field errors
        expect(response.body).to include('Name can&#39;t be blank')
      expect(response.body).to include('Description can&#39;t be blank')
      expect(response.body).to include('At least one milestone description is required')
      
      # Should NOT show generic "Form data is missing" error
      expect(response.body).not_to include('Form data is missing')
      end
    end

    context 'when form is submitted without version type' do
      it 'shows validation error for missing version type' do
        post organization_abilities_path(organization), params: {
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
        expect(response.body).to include('Version type can&#39;t be blank')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/abilities/:id' do
    let(:ability) { create(:ability, organization: organization, semantic_version: '1.0.0') }

    context 'when form is submitted with valid data' do
      it 'updates the ability successfully' do
        patch organization_ability_path(organization, ability), params: {
          ability: {
            name: 'Updated Ability',
            description: 'Updated Description',
            organization_id: organization.id,
            version_type: 'fundamental',
            milestone_1_description: 'Updated milestone 1',
            milestone_2_description: 'Updated milestone 2',
            milestone_3_description: 'Updated milestone 3',
            milestone_4_description: 'Updated milestone 4',
            milestone_5_description: 'Updated milestone 5'
          }
        }

        expect(response).to have_http_status(:redirect)
        ability.reload
        expect(response).to redirect_to(organization_ability_path(organization, ability))
        expect(ability.name).to eq('Updated Ability')
        expect(ability.semantic_version).to eq('2.0.0') # Major version bump
      end
    end

    context 'when form is submitted with no data' do
      it 'shows validation errors and renders edit template' do
        patch organization_ability_path(organization, ability), params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
        expect(response.body).to include('Form data is missing')
      end
    end
  end

  describe 'GET /organizations/:organization_id/abilities' do
    let!(:ability_v1) { create(:ability, organization: organization, semantic_version: '1.0.0', name: 'Ability v1') }
    let!(:ability_v1_2) { create(:ability, organization: organization, semantic_version: '1.2.3', name: 'Ability v1.2') }
    let!(:ability_v2) { create(:ability, organization: organization, semantic_version: '2.0.0', name: 'Ability v2') }
    let!(:ability_v0) { create(:ability, organization: organization, semantic_version: '0.1.0', name: 'Ability v0') }

    before do
      teammate
      sign_in_as_teammate_for_request(person, organization)
    end

    it 'filters by major version 1' do
      get organization_abilities_path(organization, major_version: 1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ability v1')
      expect(response.body).to include('Ability v1.2')
      expect(response.body).not_to include('Ability v2')
      expect(response.body).not_to include('Ability v0')
    end

    it 'filters by major version 2' do
      get organization_abilities_path(organization, major_version: 2)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ability v2')
      expect(response.body).not_to include('Ability v1')
      expect(response.body).not_to include('Ability v1.2')
      expect(response.body).not_to include('Ability v0')
    end

    it 'filters by major version 0' do
      get organization_abilities_path(organization, major_version: 0)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ability v0')
      expect(response.body).not_to include('Ability v1')
      expect(response.body).not_to include('Ability v1.2')
      expect(response.body).not_to include('Ability v2')
    end

    it 'shows all abilities when major_version is empty' do
      get organization_abilities_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ability v1')
      expect(response.body).to include('Ability v1.2')
      expect(response.body).to include('Ability v2')
      expect(response.body).to include('Ability v0')
    end
  end
end
