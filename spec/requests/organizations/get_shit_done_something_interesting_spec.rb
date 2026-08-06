require 'rails_helper'

RSpec.describe 'Organizations::GetShitDone something_interesting', type: :request do
  let(:company) { create(:organization) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: company) }
  let(:path) { "/organizations/#{company.to_param}/get_shit_done/something_interesting" }

  before do
    sign_in_as_teammate_for_request(person, company)
  end

  describe 'GET /organizations/:organization_id/get_shit_done/something_interesting' do
    it 'renders the page with tabs' do
      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Something Interesting')
      expect(response.body).not_to include('badge text-bg-warning')
      expect(response.body).to include(organization_get_shit_done_path(company))
    end

    it 'defaults to the last 7 days on a first visit' do
      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('This is your first visit')
    end

    it 'defaults the since date to the last visit when one exists' do
      create(:page_visit, person: person, url: path, visited_at: 1.day.ago)

      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Defaults to your last visit')
    end

    it 'shows goals updated by direct reports' do
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      goal = create(:goal, owner: report, creator: report, company: company, title: "Interesting Report Goal #{SecureRandom.hex(4)}", goal_type: 'quantitative_key_result')

      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(goal.title)
      expect(response.body).to include('Goals updated by those I serve')
    end

    it 'respects an explicit since param' do
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      goal = create(:goal, owner: report, creator: report, company: company, title: "Old Goal #{SecureRandom.hex(4)}", goal_type: 'quantitative_key_result')
      goal.update_column(:updated_at, 3.days.ago)

      get path, params: { since: 10.days.ago.to_date.to_s }
      expect(response.body).to include(goal.title)

      get path, params: { since: 1.day.ago.to_date.to_s }
      expect(response.body).not_to include(goal.title)
    end

    it 'lists quiet categories when nothing interesting happened' do
      get path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('nothing interesting has happened')
      expect(response.body).to include(CGI.escapeHTML("Goals updated on teams I'm on"))
      expect(response.body).to include(CGI.escapeHTML("Assignments updated that I'm interested in"))
      expect(response.body).to include(CGI.escapeHTML("Abilities updated that I'm interested in"))
      expect(response.body).to include('Observations made about those I serve')
      expect(response.body).to include('Observations made about me')
    end

    it 'requires authentication' do
      sign_out_teammate_for_request

      get path

      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'tab pill on the Get Shit Done page' do
    it 'shows an info pill with the count of interesting things since the last visit' do
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      create(:goal, owner: report, creator: report, company: company, goal_type: 'quantitative_key_result')

      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('text-bg-info')
      expect(response.body).to include('Something Interesting')
    end

    it 'does not show the pill when the last visit is newer than all activity' do
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      create(:goal, owner: report, creator: report, company: company, goal_type: 'quantitative_key_result')
      create(:page_visit, person: person, url: path, visited_at: 1.minute.from_now)

      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Something Interesting')
      expect(response.body).not_to include('badge rounded-pill text-bg-info')
    end
  end

  describe 'header attention pill' do
    it 'shows a blue pill with interesting count when GSD is empty' do
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      create(:goal, owner: report, creator: report, company: company, goal_type: 'quantitative_key_result')

      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('header-gsd-pill__interesting')
      expect(response.body).to include(something_interesting_organization_get_shit_done_path(company))
      expect(response.body).not_to include('header-gsd-pill__si-dot')
    end

    it 'shows a red GSD pill with a clickable blue SI dot when both have items' do
      create(:observation, observer: person, company: company, published_at: nil)
      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      create(:goal, owner: report, creator: report, company: company, goal_type: 'quantitative_key_result')

      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('header-gsd-pill__count')
      expect(response.body).to include('bg-danger')
      expect(response.body).to include('header-gsd-pill__si-dot')
      expect(response.body).to include(organization_get_shit_done_path(company))
    end

    it 'does not show a header pill when both queues are empty' do
      create(:page_visit, person: person, url: path, visited_at: Time.current)

      get "/organizations/#{company.to_param}/get_shit_done"

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('header-gsd-pill')
      expect(response.body).not_to include('header-gsd-pill__interesting')
    end

    it 'clears the cached header SI count after visiting Something Interesting' do
      previous_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new

      report = create(:teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: teammate)
      create(:goal, owner: report, creator: report, company: company, goal_type: 'quantitative_key_result')

      Rails.cache.write(
        SomethingInterestingQueryService.header_pending_count_cache_key(teammate),
        5,
        expires_in: 1.hour
      )

      get path

      expect(response).to have_http_status(:success)
      expect(SomethingInterestingQueryService.header_pending_count(teammate)).to eq(0)
    ensure
      Rails.cache = previous_cache
    end
  end
end
