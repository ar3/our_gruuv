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

      context 'Grow by experiences energy summary' do
        let(:assignment_one) { create(:assignment, company: organization, title: 'Delivery Lead') }
        let(:assignment_two) { create(:assignment, company: organization, title: 'Team Coach') }

        before do
          create(
            :assignment_tenure,
            teammate: employee_teammate,
            assignment: assignment_one,
            anticipated_energy_percentage: 60,
            ended_at: nil
          )
          create(
            :assignment_tenure,
            teammate: employee_teammate,
            assignment: assignment_two,
            anticipated_energy_percentage: 40,
            ended_at: nil
          )
        end

        it 'shows success summary and chart containers at 100% energy' do
          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include('alert-success')
          expect(response.body).to include('add up to 100%')
          expect(response.body).to include('my-growth-experiences-energy-pie-chart')
          expect(response.body).to include('my-growth-experiences-rating-pie-chart')
          expect(response.body).to include('Delivery Lead')
          expect(response.body).to include('Team Coach')
        end

        it 'shows warning summary and bypass link when energy is 95%' do
          employee_teammate.assignment_tenures.active.find_by(assignment: assignment_two)
            .update!(anticipated_energy_percentage: 35)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include('alert-warning')
          expect(response.body).to include('add up to 95%')
          expect(response.body).to include('assignment_tenure_check_in_bypass')
        end

        it 'shows danger summary when energy is 50%' do
          employee_teammate.assignment_tenures.active.find_by(assignment: assignment_one)
            .update!(anticipated_energy_percentage: 30)
          employee_teammate.assignment_tenures.active.find_by(assignment: assignment_two)
            .update!(anticipated_energy_percentage: 20)

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include('alert-danger')
          expect(response.body).to include('add up to 50%')
        end

        it 'includes rating bucket labels when check-ins exist' do
          create(
            :assignment_check_in,
            :officially_completed,
            teammate: employee_teammate,
            assignment: assignment_one,
            official_rating: 'meeting'
          )

          get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include('Meeting expectations')
          expect(response.body).to include('No finalized check-in')
        end
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

      context 'Grow by abilities grid' do
        let(:title) { create(:title, company: organization) }
        let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
        let(:current_position) { create(:position, title: title, position_level: position_level) }
        let(:target_title) { create(:title, company: organization) }
        let(:target_position_level) { create(:position_level, position_major_level: target_title.position_major_level) }
        let(:target_position) { create(:position, title: target_title, position_level: target_position_level) }
        let(:ability_direct) { create(:ability, company: organization, name: 'DirectAbility') }
        let(:ability_from_assignment) { create(:ability, company: organization, name: 'AssignAbility') }
        let(:assignment) { create(:assignment, company: organization, title: 'Req Assign Title') }

        before do
          employee_teammate.employment_tenures.active.first.update!(position: current_position)
          create(:position_ability, position: current_position, ability: ability_direct, milestone_level: 2)
          create(:assignment_ability, assignment: assignment, ability: ability_from_assignment, milestone_level: 3)
          create(:position_assignment, position: current_position, assignment: assignment, assignment_type: 'required')
          create(:teammate_milestone, company_teammate: employee_teammate, ability: ability_from_assignment, milestone_level: 1)
          employee_teammate.update!(next_goal_position: target_position)
          create(:position_ability, position: target_position, ability: ability_direct, milestone_level: 3)
        end

        it 'renders ability rows with Direct and assignment captions, teammate links, mileage section, and miles popovers' do
          casual = employee.reload.casual_name
          get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include('my-growth-experience-day-to-day-stack')
          expect(response.body).to include("Add a win/challenge/note (OGO) about #{casual} &amp; DirectAbility")
          expect(response.body).to include('rateable_type=Ability')
          expect(response.body).to include("rateable_id=#{ability_direct.id}")
          expect(response.body).to include('choose_manage_goals')
          expect(response.body).to include('DirectAbility')
          expect(response.body).to include('AssignAbility')
          expect(response.body).to include('Direct requires M2')
          expect(response.body).to include('requires M3')
          expect(response.body).to include('Req Assign Title')
          expect(response.body).to include(organization_teammate_assignment_path(organization, employee_teammate, assignment))
          expect(response.body).to include(organization_teammate_ability_path(organization, employee_teammate, ability_direct))
          expect(response.body).to include('my-growth-ability-miles')
          expect(response.body).to include('data-bs-toggle="popover"')
          expect(response.body).to include('Miles are a way to allow people to go after expertise')
          expect(response.body).to include('border-warning')
          expect(response.body).to include("Need (M2) for #{current_position.display_name}")
          expect(response.body).to include('my-growth-abilities-mileage-totals-rule')
          expect(response.body).to include('Miles earned')
          expect(response.body).to include('Miles needed')
        end

        it 'shows target-threshold pill when current is met but target is not' do
          create(:teammate_milestone, company_teammate: employee_teammate, ability: ability_direct, milestone_level: 2)

          get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include("Need (M3) for #{target_position.display_name}")
          expect(response.body).to include('bg-info-subtle')
        end

        it 'shows combined threshold pill when current and target share the same unmet milestone' do
          shared_ability = create(:ability, company: organization, name: 'SharedThresholdAbility')
          create(:position_ability, position: current_position, ability: shared_ability, milestone_level: 4)
          create(:position_ability, position: target_position, ability: shared_ability, milestone_level: 4)

          get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)

          expect(response.body).to include("Need (M4) for #{current_position.display_name} + #{target_position.display_name}")
        end

        it 'shows no-target alert when next goal position is blank' do
          employee_teammate.update!(next_goal_position: nil)
          get my_growth_abilities_organization_company_teammate_path(organization, employee_teammate)
          expect(response.body).to include('does not have a target position')
        end
      end

      it 'allows GET my_growth/goals' do
        get my_growth_goals_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('draft + active')
        expect(response.body).to include('Go check-in on')
        expect(response.body).to include('draft goals')
      end

      it 'allows GET my_growth/position_change' do
        get my_growth_position_change_organization_company_teammate_path(organization, employee_teammate)
        expect(response).to have_http_status(:success)
      end
    end

    context 'when employee views own growth experiences' do
      let(:own_assignment) { create(:assignment, company: organization, title: 'Solo Project') }

      before do
        sign_in_as_teammate_for_request(employee, organization)
        create(
          :assignment_tenure,
          teammate: employee_teammate,
          assignment: own_assignment,
          anticipated_energy_percentage: 50,
          ended_at: nil
        )
      end

      it 'shows danger summary without bypass link' do
        get my_growth_experiences_organization_company_teammate_path(organization, employee_teammate)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('alert-danger')
        expect(response.body).to include('add up to 50%')
        expect(response.body).not_to include('assignment_tenure_check_in_bypass')
        expect(response.body).to include('managerial hierarchy')
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
