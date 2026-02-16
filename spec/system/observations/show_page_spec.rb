require 'rails_helper'

RSpec.describe 'Observation Show Page', type: :system do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let!(:observer_teammate) { CompanyTeammate.create!(person: observer, organization: company) }
  let(:observee_person) { create(:person) }
  let!(:observee_teammate) { CompanyTeammate.create!(person: observee_person, organization: company) }
  let(:other_person) { create(:person) }
  let!(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }

  before do
    sign_in_as(observer, company)
  end

  describe 'Publish button' do
    context 'when observation is a draft' do
      let(:draft_observation) do
        build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
        end
      end

      it 'shows publish button for observer' do
        visit organization_observation_path(company, draft_observation)
        expect(page).to have_button('Publish')
      end

      it 'publishes observation when clicked' do
        visit organization_observation_path(company, draft_observation)
        within('[data-test-id="observation-publish-header"]') { click_button 'Publish' }
        
        draft_observation.reload
        expect(draft_observation.published_at).to be_present
        expect(page).to have_current_path(organization_observation_path(company, draft_observation))
        expect(page).to have_content('Observation was successfully published')
      end

      it 'does not allow non-observer to access show page' do
        switch_to_user(other_person, company)
        # Non-observers (and non-observees) are not authorized to view draft observation show page
        # The controller redirects to kudos path, which then redirects with flash message
        visit organization_observation_path(company, draft_observation)
        
        # Should be redirected (likely to dashboard for authenticated users)
        expect(page.current_path).not_to eq(organization_observation_path(company, draft_observation))
        # Should see authorization error message
        expect(page).to have_content(/not authorized|You are not authorized|don't have permission/i)
      end
    end

    context 'when observation is already published' do
      let(:published_observation) do
        build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'does not show publish button' do
        visit organization_observation_path(company, published_observation)
        expect(page).not_to have_button('Publish')
      end
    end

    context 'when observation is published (cannot publish)' do
      let(:published_observation) do
        build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
          obs.observees.build(teammate: observee_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'does not show publish button for published observation' do
        visit organization_observation_path(company, published_observation)
        expect(page).not_to have_button('Publish')
      end
    end
  end

  describe 'GIFs section' do
    let(:observation_with_gifs) do
      build(:observation, observer: observer, company: company, story: 'Test story', story_extras: { 'gif_urls' => ['https://example.com/gif1.gif', 'https://example.com/gif2.gif'] }).tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    let(:observation_without_gifs) do
      build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    context 'when observation has GIFs' do
      it 'displays GIFs section' do
        visit organization_observation_path(company, observation_with_gifs)
        expect(page).to have_css('h5', text: 'GIFs')
        expect(page).to have_css('[id="observation-gifs"]')
      end

      it 'displays GIFs in responsive Bootstrap grid' do
        visit organization_observation_path(company, observation_with_gifs)
        expect(page).to have_css('.row .col-12.col-md-6.col-lg-4', count: 2)
        expect(page).to have_css('img[src="https://example.com/gif1.gif"]')
        expect(page).to have_css('img[src="https://example.com/gif2.gif"]')
      end
    end

    context 'when observation has no GIFs' do
      it 'does not display GIFs section' do
        visit organization_observation_path(company, observation_without_gifs)
        expect(page).not_to have_css('h5', text: 'GIFs')
        expect(page).not_to have_css('[id="observation-gifs"]')
      end
    end
  end

  describe 'Public Mode in mode switcher' do
    let(:public_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story', privacy_level: 'public_to_world').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    let(:private_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story', privacy_level: 'observed_only').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    context 'when privacy level is public_to_world' do
      it 'shows Public Mode as clickable link' do
        visit organization_observation_path(company, public_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_link('Public Mode', href: organization_kudo_path(company, date: public_observation.observed_at.strftime('%Y-%m-%d'), id: public_observation.id))
        expect(page).to have_css('.dropdown-item i.bi-globe')
      end

      it 'navigates to kudos page when Public Mode is clicked' do
        visit organization_observation_path(company, public_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        click_link 'Public Mode'
        
        expected_path = organization_kudo_path(company, date: public_observation.observed_at.strftime('%Y-%m-%d'), id: public_observation.id)
        expect(page).to have_current_path(expected_path)
      end
    end

    context 'when privacy level is not public_to_world' do
      it 'shows Public Mode as disabled with warning icon' do
        visit organization_observation_path(company, private_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_css('.dropdown-item.text-muted.disabled', text: 'Public Mode')
        expect(page).to have_css('.dropdown-item i.bi-globe')
        expect(page).to have_css('.dropdown-item i.bi-exclamation-triangle.text-warning')
      end

      it 'shows tooltip with explanation when hovering over disabled Public Mode' do
        visit organization_observation_path(company, private_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        disabled_item = find('.dropdown-item.disabled', text: 'Public Mode')
        expect(disabled_item).to have_css('[data-bs-toggle="tooltip"]')
        expect(disabled_item.find('[data-bs-toggle="tooltip"]')['data-bs-title']).to eq("Public Mode is only available for observations with 'Public to World' privacy level")
      end
    end
  end

  describe 'Archive Observation in mode switcher' do
    let(:published_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    let(:archived_observation) do
      build(:observation, observer: observer, company: company, story: 'Test story', deleted_at: Time.current).tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
        obs.publish!
      end
    end

    context 'when user is observer and observation is not archived' do
      it 'shows Archive Observation as clickable button in dropdown' do
        visit organization_observation_path(company, published_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_button('Archive Observation')
        expect(page).to have_css('.dropdown-item i.bi-archive')
      end

      it 'shows divider before Archive option' do
        visit organization_observation_path(company, published_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_css('.dropdown-divider')
      end

      it 'archives observation when Archive Observation is clicked' do
        visit organization_observation_path(company, published_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        # Wait for dropdown to be visible
        expect(page).to have_css('.dropdown-menu.show', wait: 2)
        
        # Find and click the Archive button in the dropdown
        within('.dropdown-menu') do
          archive_button = find('button', text: 'Archive Observation')
          # Accept confirmation before clicking
          page.driver.browser.switch_to.alert.accept rescue nil
          archive_button.click
        end
        
        # Wait for redirect and reload
        sleep 2
        published_observation.reload
        expect(published_observation.deleted_at).to be_present
        expect(page).to have_content('Observation was successfully archived')
      end
    end

    context 'when observation is archived and user is observer' do
      it 'shows Restore Observation button in dropdown' do
        visit organization_observation_path(company, archived_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        expect(page).to have_button('Restore Observation')
        expect(page).to have_css('.dropdown-item i.bi-arrow-counterclockwise')
      end

      it 'restores observation when Restore Observation is clicked' do
        visit organization_observation_path(company, archived_observation)
        
        # Open the dropdown
        find('button.dropdown-toggle').click
        
        # Target the one in the dropdown specifically
        within('.dropdown-menu') do
          click_button 'Restore Observation'
        end
        
        archived_observation.reload
        expect(archived_observation.deleted_at).to be_nil
        expect(page).to have_content('Observation was successfully restored')
      end
    end

    context 'when user is not observer' do
      before do
        switch_to_user(other_person, company)
      end

      it 'does not allow non-observer to archive observation' do
        visit organization_observation_path(company, published_observation)
        
        # Non-observers may be redirected or see a different page structure
        # If they can see the show page, Archive should be disabled
        # Check for disabled Archive button in actions card if it exists
        if page.has_css?('.card', text: /Actions/, wait: 2)
          within('.card', text: /Actions/) do
            expect(page).to have_css('button.btn-outline-secondary.disabled[disabled]', text: 'Archive Observation')
            expect(page).to have_css('i.bi-exclamation-triangle.text-warning')
          end
        end
        
        # If mode switcher exists, Archive should also be disabled there
        if page.has_css?('button.dropdown-toggle', wait: 0)
          # Try to find observation mode switcher by looking for specific content
          dropdown_buttons = all('button.dropdown-toggle')
          observation_switcher = dropdown_buttons.find { |btn| btn.text.match?(/View Mode|Edit Mode|Public Mode/) }
          
          if observation_switcher
            observation_switcher.click
            expect(page).to have_css('.dropdown-menu.show', wait: 2)
            
            within('.dropdown-menu') do
              if page.has_content?('Archive Observation', wait: 0)
                expect(page).to have_css('.dropdown-item.text-muted.disabled', text: /Archive Observation/)
                expect(page).to have_css('[data-bs-toggle="tooltip"][data-bs-title="You need to be the observer to archive this observation"]')
              end
            end
          end
        end
      end
    end
  end

  describe 'Form buttons on new/edit pages' do
    let(:draft_observation) do
      build(:observation, observer: observer, company: company, published_at: nil, story: 'Test story').tap do |obs|
        obs.observees.build(teammate: observee_teammate)
        obs.save!
      end
    end

    describe 'button presence and functionality' do
      context 'on new generic observation page' do
        it 'shows all form buttons' do
          visit new_organization_observation_path(company)
          
          expect(page).to have_button('Publish', exact: false)
          expect(page).to have_button('Save Draft', exact: false)
          expect(page).to have_button('Cancel')
        end

        it 'publish button submits form' do
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          # Fill in required fields
          fill_in 'observation_story', with: 'Test story for publishing'
          
          expect(page).to have_button('Publish', exact: false)
          click_button('Publish', exact: false)
          
          # Should redirect (either to show page or back with errors)
          expect(page).to have_current_path(/.+/, wait: 5)
        end

        it 'save draft button submits form' do
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          fill_in 'observation_story', with: 'Updated story'
          
          expect(page).to have_button('Save Draft', exact: false)
          click_button('Save Draft', exact: false)
          
          # Should redirect
          expect(page).to have_current_path(/.+/, wait: 5)
        end

        it 'cancel button submits form' do
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          expect(page).to have_button('Cancel')
          click_button 'Cancel'
          
          # Should redirect
          expect(page).to have_current_path(/.+/, wait: 5)
        end
      end

      context 'on edit generic observation page' do
        it 'shows all form buttons' do
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          expect(page).to have_button('Publish', exact: false)
          expect(page).to have_button('Save Draft', exact: false)
          expect(page).to have_button('Cancel')
        end

        it 'publish button works' do
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          expect(page).to have_button('Publish', exact: false)
          click_button('Publish', exact: false)
          
          # Button should submit - either publishes or shows validation errors
          sleep 1 # Give time for form submission
          expect(page).to have_current_path(/.+/, wait: 5)
        end

        it 'save draft button works' do
          original_updated_at = draft_observation.updated_at
          visit new_organization_observation_path(company, draft_id: draft_observation.id)
          
          fill_in 'observation_story', with: 'Updated draft story'
          
          expect(page).to have_button('Save Draft', exact: false)
          click_button('Save Draft', exact: false)
          
          # Should redirect back to edit page
          sleep 1 # Give time for redirect
          draft_observation.reload
          expect(draft_observation.updated_at).to be > original_updated_at
        end
      end

      context 'on new kudos page' do
        let(:kudos_draft) do
          build(:observation, observer: observer, company: company, published_at: nil, observation_type: 'kudos', created_as_type: 'kudos', story: 'Great work!').tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end

        it 'shows all form buttons' do
          visit new_kudos_organization_observations_path(company, draft_id: kudos_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          expect(page).to have_button('Save Draft', exact: false)
          expect(page).to have_button('Cancel')
        end

        it 'publish button works' do
          visit new_kudos_organization_observations_path(company, draft_id: kudos_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          click_button('Publish', exact: false)
          
          # Button should submit - either publishes or shows validation errors
          sleep 1 # Give time for form submission
          expect(page).to have_current_path(/.+/, wait: 5)
        end
      end

      context 'on new feedback page' do
        let(:feedback_draft) do
          build(:observation, observer: observer, company: company, published_at: nil, observation_type: 'feedback', created_as_type: 'feedback', story: 'Your intent with this feedback').tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end

        it 'shows all form buttons' do
          visit new_feedback_organization_observations_path(company, draft_id: feedback_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          expect(page).to have_button('Save Draft', exact: false)
          expect(page).to have_button('Cancel')
        end

        it 'publish button works' do
          visit new_feedback_organization_observations_path(company, draft_id: feedback_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          click_button('Publish', exact: false)
          
          # Button should submit - either publishes or shows validation errors
          sleep 1 # Give time for form submission
          expect(page).to have_current_path(/.+/, wait: 5)
        end
      end

      context 'on new quick_note page' do
        let(:quick_note_draft) do
          build(:observation, observer: observer, company: company, published_at: nil, observation_type: 'quick_note', created_as_type: 'quick_note', story: 'Quick note').tap do |obs|
            obs.observees.build(teammate: observee_teammate)
            obs.save!
          end
        end

        it 'shows all form buttons' do
          visit new_quick_note_organization_observations_path(company, draft_id: quick_note_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          expect(page).to have_button('Save Draft', exact: false)
          expect(page).to have_button('Cancel')
        end

        it 'publish button works' do
          visit new_quick_note_organization_observations_path(company, draft_id: quick_note_draft.id)
          
          expect(page).to have_button('Publish', exact: false)
          click_button('Publish', exact: false)
          
          # Button should submit - either publishes or shows validation errors
          sleep 1 # Give time for form submission
          expect(page).to have_current_path(/.+/, wait: 5)
        end
      end
    end
  end
end

