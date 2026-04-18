require 'rails_helper'

RSpec.describe 'Company teammate My Growth', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
  let(:employee) { create(:person) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:peer) { create(:person) }
  let(:peer_teammate) { create(:teammate, person: peer, organization: organization) }

  before do
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: employee_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: peer_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    employee_teammate.update!(first_employed_at: 1.year.ago)
    peer_teammate.update!(first_employed_at: 1.year.ago)
  end

  describe 'authorization' do
    context 'when manager views direct report' do
      before do
        employee_teammate.employment_tenures.active.first&.update!(manager_teammate: manager_teammate)
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows GET my_growth/experiences' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Growth')
      end

      it 'offers show/hide suggested assignments with query param and anchor id' do
        et = employee_teammate.employment_tenures.active.first
        position = et.position
        assignment_required = create(:assignment, company: organization, title: 'Required Active Row')
        assignment_suggested = create(:assignment, company: organization, title: 'Suggested Only Row')
        create(:position_assignment, position: position, assignment: assignment_required, assignment_type: 'required')
        create(:position_assignment, :suggested, position: position, assignment: assignment_suggested)
        create(:assignment_tenure, teammate: employee_teammate, assignment: assignment_required)

        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response.body).to include('Show suggested assignments')
        expect(response.body).to include('show_suggested=true')
        expect(response.body).to include('suggested-assignments-toggle')

        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate, show_suggested: true)
        expect(response.body).to include('Hide suggested assignments')
        expect(response.body).to include('Suggested Only Row')
      end

      context 'Grow by experiences assignment cards' do
        let(:assignment) { create(:assignment, company: organization, title: 'North Star Delivery') }
        let(:base_goal_attrs) do
          {
            company_id: organization.id,
            creator: manager_teammate,
            owner: employee_teammate,
            goal_type: 'inspirational_objective',
            most_likely_target_date: nil,
            earliest_target_date: nil,
            latest_target_date: nil,
            completed_at: nil,
            deleted_at: nil
          }
        end
        let(:started_goal_attrs) { base_goal_attrs.merge(started_at: 1.day.ago) }
        let(:draft_goal_attrs) { base_goal_attrs.merge(started_at: nil) }

        before do
          employee.update!(first_name: 'Jamie', last_name: 'Rivera')
          create(:assignment_tenure, teammate: employee_teammate, assignment: assignment)
        end

        it 'shows set-goal link when there is no incomplete unarchived goal for that assignment and teammate' do
          casual = employee_teammate.reload.person.casual_name
          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Set goal for #{casual} &amp; #{assignment.title}")
          expect(response.body).to include("/assignments/#{assignment.to_param}/choose_manage_goals")
          expect(response.body).to include("for_company_teammate_id=#{employee_teammate.id}")
        end

        it 'includes OGO deep link with observee and assignment rateable' do
          casual = employee_teammate.reload.person.casual_name
          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include('/observations/new')
          expect(response.body).to include("observee_ids%5B%5D=#{employee_teammate.id}")
          expect(response.body).to include('rateable_type=Assignment')
          expect(response.body).to include("rateable_id=#{assignment.id}")
          expect(response.body).to include("Add a win/challenge/note (OGO) about #{casual} &amp; #{assignment.title}")
        end

        it 'preserves show_suggested in return_url for OGO and goal links when present' do
          get my_growth_experiences_organization_company_teammate_path(
            organization,
            employee_teammate,
            show_suggested: true
          )
          expect(response.body).to include('show_suggested%3Dtrue')
        end

        it 'shows add-to-goals when an associated goal is started (incomplete and unarchived)' do
          casual = employee_teammate.reload.person.casual_name
          goal = create(:goal, **started_goal_attrs)
          create(:goal_association, goal: goal, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Add to the 1 active goal for #{casual} &amp; #{assignment.title}")
        end

        it 'shows add-to-goals when an associated goal is still a draft (incomplete and unarchived)' do
          casual = employee_teammate.reload.person.casual_name
          goal = create(:goal, **draft_goal_attrs)
          create(:goal_association, goal: goal, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Add to the 1 active goal for #{casual} &amp; #{assignment.title}")
        end

        it 'still shows set-goal when the only associated goals are completed' do
          casual = employee_teammate.reload.person.casual_name
          g = create(:goal, **started_goal_attrs.merge(completed_at: 1.day.ago))
          create(:goal_association, goal: g, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Set goal for #{casual} &amp; #{assignment.title}")
        end

        it 'still shows set-goal when the only associated goals are archived (soft-deleted)' do
          casual = employee_teammate.reload.person.casual_name
          g = create(:goal, **started_goal_attrs.merge(deleted_at: 1.day.ago))
          create(:goal_association, goal: g, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Set goal for #{casual} &amp; #{assignment.title}")
        end

        it 'counts only open goals when mixing completed and open associations' do
          casual = employee_teammate.reload.person.casual_name
          open_g = create(:goal, **started_goal_attrs.merge(title: 'Open'))
          done_g = create(:goal, **started_goal_attrs.merge(title: 'Done', completed_at: 1.day.ago))
          create(:goal_association, goal: open_g, associable: assignment)
          create(:goal_association, goal: done_g, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Add to the 1 active goal for #{casual} &amp; #{assignment.title}")
        end

        it 'pluralizes when multiple incomplete unarchived goals are associated' do
          casual = employee_teammate.reload.person.casual_name
          g1 = create(:goal, **started_goal_attrs.merge(title: 'First linked goal'))
          g2 = create(:goal, **started_goal_attrs.merge(title: 'Second linked goal'))
          create(:goal_association, goal: g1, associable: assignment)
          create(:goal_association, goal: g2, associable: assignment)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include("Add to the 2 active goals for #{casual} &amp; #{assignment.title}")
        end
      end

      it 'allows GET my_growth/abilities' do
        get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end

      it 'allows GET my_growth/goals' do
        get my_growth_goals_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("View and check-in on all of #{employee.casual_name}'s goals")
      end

      it 'allows GET my_growth/position_change' do
        get my_growth_position_change_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when peer (no hierarchy) views another employee' do
      before { sign_in_as_teammate_for_request(peer, organization) }

      it 'denies my_growth/experiences' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context 'when unauthenticated' do
      it 'redirects to login' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH update_next_goal_position' do
    let(:title) { create(:title, company: organization) }
    let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
    let(:position) { create(:position, title: title, position_level: position_level) }

    before do
      employee_teammate.employment_tenures.active.first&.update!(manager_teammate: manager_teammate)
      sign_in_as_teammate_for_request(manager, organization)
    end

    it 'updates next_goal_position_id' do
      patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
            params: { next_goal_position_id: position.id }
      expect(response).to redirect_to(my_growth_position_change_organization_company_teammate_path(organization, employee_teammate))
      expect(employee_teammate.reload.next_goal_position_id).to eq(position.id)
    end

    it 'clears next_goal_position_id when blank' do
      employee_teammate.update!(next_goal_position: position)
      patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
            params: { next_goal_position_id: '' }
      expect(employee_teammate.reload.next_goal_position_id).to be_nil
    end

    context 'when position is for another company' do
      let(:other_title) { create(:title, company: other_organization) }
      let(:other_level) { create(:position_level, position_major_level: other_title.position_major_level) }
      let(:other_position) { create(:position, title: other_title, position_level: other_level) }

      it 'rejects the update' do
        patch update_next_goal_position_organization_company_teammate_path(organization, employee_teammate),
              params: { next_goal_position_id: other_position.id }
        expect(employee_teammate.reload.next_goal_position_id).to be_nil
        expect(flash[:alert]).to be_present
      end
    end
  end
end
