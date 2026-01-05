require 'rails_helper'

RSpec.describe 'Get Shit Done Dashboard', type: :system do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: company, person: person) }
  
  before do
    sign_in_as(person, company)
  end
  
  describe 'dashboard display' do
    it 'displays all pending items' do
      # Create pending items
      observable_moment = create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate)
      maap_snapshot = create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: nil)
      draft_observation = create(:observation, observer: person, company: company, published_at: nil)
      goal = create(:goal, owner: teammate, company: company, started_at: Time.current)
      
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content('Get Shit Done')
      expect(page).to have_content('Observable Moments')
      expect(page).to have_content('MAAP Snapshots')
      expect(page).to have_content('Observation Drafts')
      expect(page).to have_content('Goal Check-ins')
    end
    
    it 'shows observable moments section with pending moments' do
      moment1 = create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate)
      moment2 = create(:observable_moment, :seat_change, company: company, primary_potential_observer: teammate)
      other_teammate = create(:teammate, organization: company)
      moment3 = create(:observable_moment, :new_hire, company: company, primary_potential_observer: other_teammate)
      
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content(moment1.display_name)
      expect(page).to have_content(moment2.display_name)
      expect(page).not_to have_content(moment3.display_name)
    end
    
    it 'shows MAAP snapshots section with pending acknowledgements' do
      snapshot1 = create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: nil)
      snapshot2 = create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: Time.current)
      other_person = create(:person)
      snapshot3 = create(:maap_snapshot, employee: other_person, company: company, employee_acknowledged_at: nil)
      
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content(snapshot1.change_type.humanize)
      expect(page).not_to have_content(snapshot2.change_type.humanize)
      expect(page).not_to have_content(snapshot3.change_type.humanize)
    end
    
    it 'shows observation drafts section' do
      draft1 = create(:observation, observer: person, company: company, published_at: nil, story: 'Draft story 1')
      draft2 = create(:observation, observer: person, company: company, published_at: nil, story: 'Draft story 2')
      published = create(:observation, observer: person, company: company, published_at: Time.current)
      other_person = create(:person)
      other_draft = create(:observation, observer: other_person, company: company, published_at: nil)
      
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content('Draft story 1')
      expect(page).to have_content('Draft story 2')
      expect(page).not_to have_content(published.story)
      expect(page).not_to have_content(other_draft.story)
    end
    
    it 'shows goals needing check-in' do
      goal1 = create(:goal, owner: teammate, company: company, started_at: Time.current, title: 'Goal 1')
      goal2 = create(:goal, owner: teammate, company: company, started_at: Time.current, title: 'Goal 2')
      create(:goal_check_in, goal: goal1, check_in_week_start: 2.weeks.ago.beginning_of_week(:monday))
      # goal2 has no check-ins
      
      visit get_shit_done_organization_path(company)
      
      expect(page).to have_content('Goal 1')
      expect(page).to have_content('Goal 2')
    end
  end
  
  describe 'navigation badge' do
    it 'displays badge count when there are pending items' do
      create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate)
      create(:maap_snapshot, employee: person, company: company, employee_acknowledged_at: nil)
      
      visit dashboard_organization_path(company)
      
      # Check for badge in navigation
      expect(page).to have_css('.badge', text: '2')
    end
    
    it 'does not display badge when there are no pending items' do
      visit dashboard_organization_path(company)
      
      # Badge should not be visible when count is 0
      expect(page).not_to have_css('.badge.bg-danger')
    end
    
    it 'badge links to dashboard' do
      create(:observable_moment, :new_hire, company: company, primary_potential_observer: teammate)
      
      visit dashboard_organization_path(company)
      
      badge_link = find('.badge.bg-danger')
      badge_link.click
      
      expect(current_path).to eq(get_shit_done_organization_path(company))
    end
  end
end

