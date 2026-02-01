require 'rails_helper'

RSpec.describe 'Organizations::CelebrateMilestones', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.find(create(:teammate, person: person, organization: organization).id) }
  
  let(:ability1) { create(:ability, company: organization, name: 'Ruby Programming', created_by: person, updated_by: person) }
  let(:ability2) { create(:ability, company: organization, name: 'JavaScript', created_by: person, updated_by: person) }
  
  let(:person1) { create(:person, first_name: 'Alice', last_name: 'Smith') }
  let(:person2) { create(:person, first_name: 'Bob', last_name: 'Jones') }
  let(:person3) { create(:person, first_name: 'Charlie', last_name: 'Brown') }
  
  let(:teammate1) { CompanyTeammate.find(create(:teammate, person: person1, organization: organization).id) }
  let(:teammate2) { CompanyTeammate.find(create(:teammate, person: person2, organization: organization).id) }
  let(:teammate3) { CompanyTeammate.find(create(:teammate, person: person3, organization: organization).id) }
  
  let(:certifier_teammate) { CompanyTeammate.find(create(:teammate, person: create(:person), organization: organization).id) }
  
  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
    allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
    allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(teammate)
  end

  describe 'GET /organizations/:id/celebrate_milestones' do
    it 'renders successfully' do
      get celebrate_milestones_organization_path(organization)
      expect(response).to be_successful
    end

    it 'sets up all required instance variables' do
      # Create at least one published milestone for the test
      create(:teammate_milestone,
             teammate: teammate1,
             ability: ability1,
             milestone_level: 1,
             published_at: Time.current,
             published_by_teammate: certifier_teammate,
             certifying_teammate: certifier_teammate,
             attained_at: 10.days.ago)
      
      get celebrate_milestones_organization_path(organization)
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:recent_milestones)).to be_present
      expect(assigns(:milestones_by_person)).to be_present
      expect(assigns(:current_filters)).to be_a(Hash)
      expect(assigns(:current_sort)).to be_present
      expect(assigns(:current_view)).to be_present
      expect(assigns(:current_spotlight)).to be_present
    end

    describe 'filtering by privacy' do
      let!(:published_milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:private_milestone) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability1,
               milestone_level: 2,
               published_at: nil,
               certifying_teammate: certifier_teammate,
               attained_at: 5.days.ago)
      end

      it 'defaults to showing only published milestones' do
        get celebrate_milestones_organization_path(organization)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(published_milestone)
        expect(milestones).not_to include(private_milestone)
      end

      it 'filters to show only published when privacy=published' do
        get celebrate_milestones_organization_path(organization, privacy: 'published')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(published_milestone)
        expect(milestones).not_to include(private_milestone)
      end

      it 'filters to show only private when privacy=private' do
        get celebrate_milestones_organization_path(organization, privacy: 'private')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).not_to include(published_milestone)
        expect(milestones).to include(private_milestone)
      end
    end

    describe 'filtering by timeframe' do
      let!(:today_milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: Date.current)
      end
      
      let!(:week_milestone) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability1,
               milestone_level: 2,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 3.days.ago)
      end
      
      let!(:old_milestone) do
        # Create a milestone that's definitely more than 90 days ago
        # Use 100 days ago to ensure it's outside the 90-day window
        create(:teammate_milestone,
               teammate: teammate3,
               ability: ability1,
               milestone_level: 3,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 100.days.ago.to_date)
      end
      
      let!(:old_milestone_this_year) do
        # Create a milestone from earlier in the current year for this_year test
        # Use beginning of year + 1 day if we're past that, otherwise use a date from earlier in the year
        past_date = if Date.current.beginning_of_year + 100.days <= Date.current
          Date.current.beginning_of_year + 1.day
        else
          # If we're early in the year, use a date from last year that will be in this_year filter
          # Actually, if we're this early, just use beginning_of_year
          Date.current.beginning_of_year
        end
        create(:teammate_milestone,
               teammate: teammate3,
               ability: ability2,
               milestone_level: 4,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: past_date)
      end

      it 'filters by today' do
        get celebrate_milestones_organization_path(organization, timeframe: 'today')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).not_to include(week_milestone)
        expect(milestones).not_to include(old_milestone)
      end

      it 'filters by this_week' do
        get celebrate_milestones_organization_path(organization, timeframe: 'this_week')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).to include(week_milestone)
        expect(milestones).not_to include(old_milestone)
      end

      it 'filters by last_30_days' do
        get celebrate_milestones_organization_path(organization, timeframe: 'last_30_days')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).to include(week_milestone)
        expect(milestones).not_to include(old_milestone)
      end

      it 'filters by last_90_days' do
        get celebrate_milestones_organization_path(organization, timeframe: 'last_90_days')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).to include(week_milestone)
        expect(milestones).not_to include(old_milestone)
      end

      it 'filters by this_year' do
        get celebrate_milestones_organization_path(organization, timeframe: 'this_year')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).to include(week_milestone)
        expect(milestones).to include(old_milestone_this_year)
        # old_milestone might be from previous year, so don't check it
      end

      it 'shows all time when timeframe=all' do
        get celebrate_milestones_organization_path(organization, timeframe: 'all')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(today_milestone)
        expect(milestones).to include(week_milestone)
        expect(milestones).to include(old_milestone)
      end
    end

    describe 'filtering by ability' do
      let!(:milestone1) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:milestone2) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability2,
               milestone_level: 2,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 5.days.ago)
      end

      it 'filters by specific ability' do
        get celebrate_milestones_organization_path(organization, ability: ability1.id)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone1)
        expect(milestones).not_to include(milestone2)
      end

      it 'shows all abilities when no filter' do
        get celebrate_milestones_organization_path(organization)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone1)
        expect(milestones).to include(milestone2)
      end
    end

    describe 'filtering by milestone level' do
      let!(:level1_milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:level3_milestone) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability1,
               milestone_level: 3,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 5.days.ago)
      end
      
      let!(:level5_milestone) do
        create(:teammate_milestone,
               teammate: teammate3,
               ability: ability1,
               milestone_level: 5,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 2.days.ago)
      end

      it 'filters by specific milestone level' do
        get celebrate_milestones_organization_path(organization, milestone_level: 3)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(level3_milestone)
        expect(milestones).not_to include(level1_milestone)
        expect(milestones).not_to include(level5_milestone)
      end

      it 'shows all levels when no filter' do
        get celebrate_milestones_organization_path(organization)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(level1_milestone)
        expect(milestones).to include(level3_milestone)
        expect(milestones).to include(level5_milestone)
      end
    end

    describe 'filtering by person' do
      let!(:person1_milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:person2_milestone) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability1,
               milestone_level: 2,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 5.days.ago)
      end

      it 'filters by specific person' do
        get celebrate_milestones_organization_path(organization, person: person1.id)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(person1_milestone)
        expect(milestones).not_to include(person2_milestone)
      end

      it 'shows all people when no filter' do
        get celebrate_milestones_organization_path(organization)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(person1_milestone)
        expect(milestones).to include(person2_milestone)
      end
    end

    describe 'sorting' do
      let!(:old_milestone) do
        create(:teammate_milestone,
               teammate: teammate1, # Alice Smith
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:new_milestone) do
        create(:teammate_milestone,
               teammate: teammate2, # Bob Jones
               ability: ability1,
               milestone_level: 2,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 2.days.ago)
      end

      it 'defaults to sorting by attained_at descending' do
        get celebrate_milestones_organization_path(organization)
        
        milestones = assigns(:recent_milestones).to_a
        expect(milestones.first).to eq(new_milestone)
        expect(milestones.last).to eq(old_milestone)
      end

      it 'sorts by attained_at ascending' do
        get celebrate_milestones_organization_path(organization, sort: 'attained_at_asc')
        
        milestones = assigns(:recent_milestones).to_a
        expect(milestones.first).to eq(old_milestone)
        expect(milestones.last).to eq(new_milestone)
      end

      it 'sorts by person name ascending' do
        get celebrate_milestones_organization_path(organization, sort: 'person_name_asc')
        
        milestones = assigns(:recent_milestones).to_a
        # Jones comes before Smith alphabetically (ascending)
        alice_index = milestones.index { |m| m.teammate.person.last_name == 'Smith' }
        bob_index = milestones.index { |m| m.teammate.person.last_name == 'Jones' }
        expect(bob_index).to be < alice_index
      end

      it 'sorts by person name descending' do
        get celebrate_milestones_organization_path(organization, sort: 'person_name_desc')
        
        milestones = assigns(:recent_milestones).to_a
        # Smith comes before Jones (descending - reverse alphabetical)
        alice_index = milestones.index { |m| m.teammate.person.last_name == 'Smith' }
        bob_index = milestones.index { |m| m.teammate.person.last_name == 'Jones' }
        expect(alice_index).to be < bob_index
      end

      it 'sorts by ability name ascending' do
        milestone_js = create(:teammate_milestone,
                             teammate: teammate3,
                             ability: ability2,
                             milestone_level: 1,
                             published_at: Time.current,
                             published_by_teammate: certifier_teammate,
                             certifying_teammate: certifier_teammate,
                             attained_at: 1.day.ago)
        
        get celebrate_milestones_organization_path(organization, sort: 'ability_name_asc')
        
        milestones = assigns(:recent_milestones).to_a
        # JavaScript should come before Ruby Programming
        js_index = milestones.index(milestone_js)
        ruby_index = milestones.index { |m| m.ability == ability1 }
        expect(js_index).to be < ruby_index
      end

      it 'sorts by milestone level descending' do
        level5_milestone = create(:teammate_milestone,
                                  teammate: teammate3,
                                  ability: ability1,
                                  milestone_level: 5,
                                  published_at: Time.current,
                                  published_by_teammate: certifier_teammate,
                                  certifying_teammate: certifier_teammate,
                                  attained_at: 1.day.ago)
        
        get celebrate_milestones_organization_path(organization, sort: 'milestone_level_desc')
        
        milestones = assigns(:recent_milestones).to_a
        expect(milestones.first).to eq(level5_milestone)
      end

      it 'sorts by milestone level ascending' do
        level5_milestone = create(:teammate_milestone,
                                  teammate: teammate3,
                                  ability: ability1,
                                  milestone_level: 5,
                                  published_at: Time.current,
                                  published_by_teammate: certifier_teammate,
                                  certifying_teammate: certifier_teammate,
                                  attained_at: 1.day.ago)
        
        get celebrate_milestones_organization_path(organization, sort: 'milestone_level_asc')
        
        milestones = assigns(:recent_milestones).to_a
        expect(milestones.last).to eq(level5_milestone)
      end
    end

    describe 'view styles' do
      let!(:milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end

      it 'defaults to wall_badge view' do
        get celebrate_milestones_organization_path(organization)
        expect(assigns(:current_view)).to eq('wall_badge')
      end

      it 'sets wall_trophy view' do
        get celebrate_milestones_organization_path(organization, view: 'wall_trophy')
        expect(assigns(:current_view)).to eq('wall_trophy')
        expect(response.body).to include('wall_trophy')
      end

      it 'sets wall_badge view' do
        get celebrate_milestones_organization_path(organization, view: 'wall_badge')
        expect(assigns(:current_view)).to eq('wall_badge')
        expect(response.body).to include('wall_badge')
      end

      it 'sets wall_confetti view' do
        get celebrate_milestones_organization_path(organization, view: 'wall_confetti')
        expect(assigns(:current_view)).to eq('wall_confetti')
        expect(response.body).to include('wall_confetti')
      end

      it 'sets table view' do
        get celebrate_milestones_organization_path(organization, view: 'table')
        expect(assigns(:current_view)).to eq('table')
        expect(response.body).to include('table')
      end

      it 'sets list view' do
        get celebrate_milestones_organization_path(organization, view: 'list')
        expect(assigns(:current_view)).to eq('list')
        expect(response.body).to include('list')
      end

      it 'supports viewStyle parameter' do
        get celebrate_milestones_organization_path(organization, viewStyle: 'wall_badge')
        expect(assigns(:current_view)).to eq('wall_badge')
      end

      it 'prefers view over viewStyle' do
        get celebrate_milestones_organization_path(organization, view: 'wall_trophy', viewStyle: 'wall_badge')
        expect(assigns(:current_view)).to eq('wall_trophy')
      end
    end

    describe 'spotlights' do
      let!(:recent_milestone) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 1.day.ago)
      end
      
      let!(:level5_milestone) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability1,
               milestone_level: 5,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
      end
      
      let!(:old_milestone) do
        create(:teammate_milestone,
               teammate: teammate3,
               ability: ability2,
               milestone_level: 3,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 50.days.ago)
      end

      it 'defaults to overview spotlight' do
        get celebrate_milestones_organization_path(organization)
        expect(assigns(:current_spotlight)).to eq('overview')
      end

      it 'sets overview spotlight' do
        get celebrate_milestones_organization_path(organization, spotlight: 'overview')
        expect(assigns(:current_spotlight)).to eq('overview')
        expect(response.body).to include('overview')
      end

      it 'sets high_achievers spotlight' do
        get celebrate_milestones_organization_path(organization, spotlight: 'high_achievers')
        expect(assigns(:current_spotlight)).to eq('high_achievers')
        expect(response.body).to include('high_achievers')
      end

      it 'sets level_5 spotlight' do
        get celebrate_milestones_organization_path(organization, spotlight: 'level_5')
        expect(assigns(:current_spotlight)).to eq('level_5')
        expect(response.body).to include('level_5')
      end

      it 'sets recent spotlight' do
        get celebrate_milestones_organization_path(organization, spotlight: 'recent')
        expect(assigns(:current_spotlight)).to eq('recent')
        expect(response.body).to include('recent')
      end
    end

    describe 'combined filters' do
      let!(:milestone1) do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 3,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 5.days.ago)
      end
      
      let!(:milestone2) do
        create(:teammate_milestone,
               teammate: teammate2,
               ability: ability2,
               milestone_level: 5,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 2.days.ago)
      end

      it 'combines multiple filters' do
        get celebrate_milestones_organization_path(organization,
                                                   ability: ability1.id,
                                                   milestone_level: 3,
                                                   timeframe: 'last_30_days')
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone1)
        expect(milestones).not_to include(milestone2)
      end

      it 'combines filters with sorting' do
        get celebrate_milestones_organization_path(organization,
                                                   ability: ability1.id,
                                                   sort: 'attained_at_asc')
        
        milestones = assigns(:recent_milestones).to_a
        expect(milestones).to include(milestone1)
        expect(milestones).not_to include(milestone2)
      end

      it 'combines filters with view style' do
        get celebrate_milestones_organization_path(organization,
                                                   ability: ability1.id,
                                                   view: 'wall_badge')
        
        expect(assigns(:current_view)).to eq('wall_badge')
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone1)
      end

      it 'combines filters with spotlight' do
        get celebrate_milestones_organization_path(organization,
                                                   ability: ability1.id,
                                                   spotlight: 'overview')
        
        expect(assigns(:current_spotlight)).to eq('overview')
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone1)
      end
    end

    describe 'current_filters tracking' do
      it 'tracks privacy filter' do
        get celebrate_milestones_organization_path(organization, privacy: 'published')
        expect(assigns(:current_filters)[:privacy]).to eq('published')
      end

      it 'tracks timeframe filter' do
        get celebrate_milestones_organization_path(organization, timeframe: 'last_30_days')
        expect(assigns(:current_filters)[:timeframe]).to eq('last_30_days')
      end

      it 'tracks ability filter' do
        get celebrate_milestones_organization_path(organization, ability: ability1.id)
        expect(assigns(:current_filters)[:ability]).to eq(ability1.id.to_s)
      end

      it 'tracks milestone_level filter' do
        get celebrate_milestones_organization_path(organization, milestone_level: 3)
        expect(assigns(:current_filters)[:milestone_level]).to eq('3')
      end

      it 'tracks person filter' do
        get celebrate_milestones_organization_path(organization, person: person1.id)
        expect(assigns(:current_filters)[:person]).to eq(person1.id.to_s)
      end
    end

    describe 'empty states' do
      it 'handles no milestones gracefully' do
        get celebrate_milestones_organization_path(organization)
        
        expect(response).to be_successful
        expect(assigns(:recent_milestones)).to be_empty
        expect(response.body).to include('No Published Milestones')
      end

      it 'handles no milestones matching filters' do
        create(:teammate_milestone,
               teammate: teammate1,
               ability: ability1,
               milestone_level: 1,
               published_at: Time.current,
               published_by_teammate: certifier_teammate,
               certifying_teammate: certifier_teammate,
               attained_at: 10.days.ago)
        
        get celebrate_milestones_organization_path(organization, ability: ability2.id)
        
        expect(response).to be_successful
        expect(assigns(:recent_milestones)).to be_empty
      end
    end

    describe 'authorization' do
      let(:other_organization) { create(:organization, :company) }
      let(:other_person) { create(:person) }
      let(:other_teammate) { CompanyTeammate.find(create(:teammate, person: other_person, organization: other_organization).id) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(other_person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(other_organization)
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(other_teammate)
      end

      it 'only shows milestones from the current organization' do
        milestone_other_org = create(:teammate_milestone,
                                     teammate: other_teammate,
                                     ability: create(:ability, company: other_organization),
                                     milestone_level: 1,
                                     published_at: Time.current,
                                     published_by_teammate: certifier_teammate,
                                     certifying_teammate: certifier_teammate,
                                     attained_at: 10.days.ago)
        
        milestone_this_org = create(:teammate_milestone,
                                    teammate: teammate1,
                                    ability: ability1,
                                    milestone_level: 1,
                                    published_at: Time.current,
                                    published_by_teammate: certifier_teammate,
                                    certifying_teammate: certifier_teammate,
                                    attained_at: 10.days.ago)
        
        get celebrate_milestones_organization_path(other_organization)
        
        milestones = assigns(:recent_milestones)
        expect(milestones).to include(milestone_other_org)
        expect(milestones).not_to include(milestone_this_org)
      end
    end
  end

  describe 'GET /organizations/:organization_id/teammate_milestones/customize_view' do
    before do
      # Ensure abilities and people are created before tests
      ability1
      ability2
      teammate1
      teammate2
      teammate3
    end

    it 'renders successfully' do
      get customize_view_organization_teammate_milestones_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders the customize view template with overlay layout' do
      get customize_view_organization_teammate_milestones_path(organization)
      expect(response).to render_template(:customize_view)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'displays the customize view title' do
      get customize_view_organization_teammate_milestones_path(organization)
      expect(response.body).to include('Customize Milestones View')
    end

    it 'loads current filters and view state from params' do
      get customize_view_organization_teammate_milestones_path(organization,
                                                                ability: ability1.id,
                                                                milestone_level: 3,
                                                                timeframe: 'last_30_days',
                                                                privacy: 'published',
                                                                person: person1.id,
                                                                sort: 'attained_at_asc',
                                                                view: 'wall_badge',
                                                                spotlight: 'high_achievers')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('wall_badge')
      expect(response.body).to include('high_achievers')
      expect(response.body).to include('attained_at_asc')
    end

    it 'sets return URL with current params' do
      get customize_view_organization_teammate_milestones_path(organization,
                                                                view: 'wall_trophy',
                                                                sort: 'attained_at_desc')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include(celebrate_milestones_organization_path(organization))
    end

    it 'displays all view style options' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      expect(response.body).to include('Table View')
      expect(response.body).to include('List View')
      expect(response.body).to include('Wall View (Trophy)')
      expect(response.body).to include('Wall View (Badge)')
      expect(response.body).to include('Wall View (Confetti)')
    end

    it 'displays all filter options' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      expect(response.body).to include('Timeframe')
      expect(response.body).to include('Ability')
      expect(response.body).to include('Milestone Level')
      expect(response.body).to include('Person')
      expect(response.body).to include('Privacy')
    end

    it 'displays all sort options' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      expect(response.body).to include('Most Recent')
      expect(response.body).to include('Oldest First')
      expect(response.body).to include('Person Name (A-Z)')
      expect(response.body).to include('Person Name (Z-A)')
      expect(response.body).to include('Ability Name (A-Z)')
      expect(response.body).to include('Ability Name (Z-A)')
      expect(response.body).to include('Milestone Level (High to Low)')
      expect(response.body).to include('Milestone Level (Low to High)')
    end

    it 'displays all spotlight options' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      expect(response.body).to include('Milestone Overview')
      expect(response.body).to include('High Achievers')
      expect(response.body).to include('Level 5 Achievements')
      expect(response.body).to include('Recent Milestones')
      expect(response.body).to include('No Spotlight')
    end

    it 'shows available abilities in the filter dropdown' do
      # Ensure abilities are created and associated with the organization
      ability1 # trigger creation
      ability2 # trigger creation
      
      get customize_view_organization_teammate_milestones_path(organization)
      
      # The abilities should be in the select dropdown
      expect(response.body).to include(ability1.name)
      expect(response.body).to include(ability2.name)
    end

    it 'shows available people in the filter dropdown' do
      # Ensure people have teammates in the organization
      teammate1 # trigger creation
      teammate2 # trigger creation
      teammate3 # trigger creation
      
      get customize_view_organization_teammate_milestones_path(organization)
      
      # The people should be in the select dropdown (only active teammates)
      expect(response.body).to include(person1.display_name)
      expect(response.body).to include(person2.display_name)
      expect(response.body).to include(person3.display_name)
    end

    it 'preserves current view state when loading' do
      get customize_view_organization_teammate_milestones_path(organization,
                                                                view: 'wall_confetti',
                                                                sort: 'milestone_level_desc',
                                                                spotlight: 'level_5')
      
      expect(response.body).to include('wall_confetti')
      expect(response.body).to include('milestone_level_desc')
      expect(response.body).to include('level_5')
    end

    it 'defaults to wall_badge view when no view specified' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      # Check that wall_badge is selected by default
      expect(response.body).to match(/id="view_wall_badge"[^>]*checked/)
    end

    it 'defaults to overview spotlight when no spotlight specified' do
      get customize_view_organization_teammate_milestones_path(organization)
      
      # Check that overview is selected by default
      expect(response.body).to match(/id="spotlight_overview"[^>]*checked/)
    end
  end

  describe 'PATCH /organizations/:organization_id/teammate_milestones/update_view' do
    it 'redirects to celebrate_milestones with view params' do
      patch update_view_organization_teammate_milestones_path(organization),
            params: {
              view: 'wall_badge',
              sort: 'attained_at_desc',
              spotlight: 'high_achievers'
            }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include(celebrate_milestones_organization_path(organization))
      expect(response.location).to include('view=wall_badge')
      expect(response.location).to include('sort=attained_at_desc')
      expect(response.location).to include('spotlight=high_achievers')
    end

    it 'redirects with filter params' do
      patch update_view_organization_teammate_milestones_path(organization),
            params: {
              ability: ability1.id,
              milestone_level: 3,
              timeframe: 'last_30_days',
              privacy: 'published'
            }
      
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("ability=#{ability1.id}")
      expect(response.location).to include('milestone_level=3')
      expect(response.location).to include('timeframe=last_30_days')
      expect(response.location).to include('privacy=published')
    end

    it 'shows success notice' do
      patch update_view_organization_teammate_milestones_path(organization),
            params: { view: 'wall_trophy' }
      
      expect(flash[:notice]).to eq('View updated successfully.')
    end

    it 'preserves all params when redirecting' do
      patch update_view_organization_teammate_milestones_path(organization),
            params: {
              view: 'table',
              sort: 'person_name_asc',
              spotlight: 'recent',
              ability: ability1.id,
              milestone_level: 2,
              timeframe: 'this_week',
              privacy: 'private',
              person: person1.id
            }
      
      expect(response).to have_http_status(:redirect)
      location = response.location
      expect(location).to include('view=table')
      expect(location).to include('sort=person_name_asc')
      expect(location).to include('spotlight=recent')
      expect(location).to include("ability=#{ability1.id}")
      expect(location).to include('milestone_level=2')
      expect(location).to include('timeframe=this_week')
      expect(location).to include('privacy=private')
      expect(location).to include("person=#{person1.id}")
    end
  end
end

