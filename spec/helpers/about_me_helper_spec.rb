require 'rails_helper'

RSpec.describe AboutMeHelper, type: :helper do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:company_teammate) { CompanyTeammate.create!(person: person, organization: company) }

  describe '#prompts_status_indicator' do
    context 'when company has no active prompts' do
      it 'returns nil' do
        result = helper.prompts_status_indicator(company_teammate)
        expect(result).to be_nil
      end
    end

    context 'when company has active prompts' do
      let!(:prompt_template) do
        create(:prompt_template, company: company, available_at: 1.day.ago)
      end

      context 'when user has no prompts' do
        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has prompts but no responses' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end

        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has prompts with empty responses' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: '')
        end

        it 'returns :red' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:red)
        end
      end

      context 'when user has responses but no active goals' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end

        it 'returns :yellow' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:yellow)
        end
      end

      context 'when user has responses and active goals associated with prompts' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end
        let!(:goal) do
          create(:goal,
                 owner: company_teammate,
                 creator: company_teammate,
                 company: company,
                 started_at: 1.day.ago,
                 deleted_at: nil,
                 completed_at: nil)
        end
        let!(:prompt_goal) do
          create(:prompt_goal, prompt: prompt, goal: goal)
        end

        it 'returns :green' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:green)
        end
      end

      context 'when user has responses but goals are not active' do
        let!(:prompt) do
          create(:prompt, company_teammate: company_teammate, prompt_template: prompt_template)
        end
        let!(:prompt_question) do
          create(:prompt_question, prompt_template: prompt_template, position: 1)
        end
        let!(:prompt_answer) do
          create(:prompt_answer, prompt: prompt, prompt_question: prompt_question, text: 'My answer')
        end
        let!(:completed_goal) do
          create(:goal,
                 owner: company_teammate,
                 creator: company_teammate,
                 company: company,
                 started_at: 1.day.ago,
                 completed_at: 1.day.ago,
                 deleted_at: nil)
        end
        let!(:prompt_goal) do
          create(:prompt_goal, prompt: prompt, goal: completed_goal)
        end

        it 'returns :yellow' do
          result = helper.prompts_status_indicator(company_teammate)
          expect(result).to eq(:yellow)
        end
      end

      context 'when company is derived from root_company' do
        let(:root_company) { create(:organization, :company) }
        let(:department) { create(:organization, :department, parent: root_company) }
        let(:department_teammate) { CompanyTeammate.create!(person: person, organization: department) }
        let!(:prompt_template) do
          create(:prompt_template, company: root_company, available_at: 1.day.ago)
        end

        it 'correctly finds active prompts from root company' do
          result = helper.prompts_status_indicator(department_teammate)
          expect(result).to eq(:red) # No prompts created yet
        end
      end
    end
  end

  describe '#shareable_observations_status_indicator' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: company) }

    context 'when no observations given or received' do
      it 'returns :red' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:red)
      end
    end

    context 'when at least 1 observation given' do
      let!(:observation_given) do
        build(:observation,
              observer: person,
              company: company,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'returns :green when given >= 1 and received >= 1' do
        observation_received = build(:observation,
                                     observer: other_person,
                                     company: company,
                                     privacy_level: :public_to_company,
                                     observed_at: 10.days.ago,
                                     published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: company_teammate)
          obs.save!
        end

        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:green)
      end

      it 'returns :yellow when given >= 1 and received = 0' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:yellow)
      end

      it 'returns :green when given >= 2 and received = 0' do
        second_observation_given = build(:observation,
                                         observer: person,
                                         company: company,
                                         privacy_level: :public_to_company,
                                         observed_at: 10.days.ago,
                                         published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:green)
      end
    end

    context 'when 0 observations given but some received' do
      let!(:observation_received) do
        build(:observation,
              observer: other_person,
              company: company,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: company_teammate)
          obs.save!
        end
      end

      it 'returns :yellow' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:yellow)
      end
    end

    context 'when observations are older than 30 days' do
      let!(:old_observation) do
        build(:observation,
              observer: person,
              company: company,
              privacy_level: :public_to_company,
              observed_at: 35.days.ago,
              published_at: 35.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'does not count them' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:red)
      end
    end

    context 'when observations are drafts' do
      let!(:draft_observation) do
        build(:observation,
              observer: person,
              company: company,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: nil).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'does not count them' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:red)
      end
    end

    context 'when observations are observer_only' do
      let!(:observer_only_observation) do
        build(:observation,
              observer: person,
              company: company,
              privacy_level: :observer_only,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end
      end

      it 'does not count them' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        expect(result).to eq(:red)
      end
    end

    context 'when there is a self-observation' do
      let!(:self_observation) do
        build(:observation,
              observer: person,
              company: company,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago,
              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: company_teammate)
          obs.save!
        end
      end

      it 'excludes self-observation from given count but includes it in received count' do
        result = helper.shareable_observations_status_indicator(company_teammate, company)
        # Self-observation should count as 0 given, 1 received = yellow
        expect(result).to eq(:yellow)
      end

      it 'returns green when self-observation plus 1+ given observation' do
        # Add a regular observation given
        regular_observation = build(:observation,
                                    observer: person,
                                    company: company,
                                    privacy_level: :public_to_company,
                                    observed_at: 10.days.ago,
                                    published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        result = helper.shareable_observations_status_indicator(company_teammate, company)
        # 1 given (regular) + 1 received (self) = green
        expect(result).to eq(:green)
      end
    end
  end

  describe '#goals_status_indicator' do
    context 'when no active goals exist' do
      it 'returns :red' do
        result = helper.goals_status_indicator(company_teammate)
        expect(result).to eq(:red)
      end
    end

    context 'when goals exist' do
      let!(:goal1) do
        create(:goal,
               owner: company_teammate,
               creator: company_teammate,
               company: company,
               started_at: 1.day.ago,
               completed_at: nil)
      end

      context 'when any goal completed in last 90 days' do
        before do
          goal1.update!(completed_at: 30.days.ago)
        end

        it 'returns :green' do
          result = helper.goals_status_indicator(company_teammate)
          expect(result).to eq(:green)
        end

        context 'even when other goals have no recent check-ins' do
          let!(:goal2) do
            create(:goal,
                   owner: company_teammate,
                   creator: company_teammate,
                   company: company,
                   started_at: 1.day.ago,
                   completed_at: nil)
          end

          it 'still returns :green (completed goal takes precedence)' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:green)
          end
        end
      end

      context 'when no goals completed in last 90 days' do
        context 'when all active goals have check-ins in past 2 weeks' do
          let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
          let(:recent_week) { cutoff_week }
          let(:confidence_reporter) { create(:person) }

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: recent_week,
                   confidence_reporter: confidence_reporter)
          end

          it 'returns :green' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:green)
          end

          context 'with multiple goals' do
            let!(:goal2) do
              create(:goal,
                     owner: company_teammate,
                     creator: company_teammate,
                     company: company,
                     started_at: 1.day.ago,
                     completed_at: nil)
            end

            before do
              create(:goal_check_in,
                     goal: goal2,
                     check_in_week_start: recent_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green when all goals have recent check-ins' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is exactly on the cutoff week' do
            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: cutoff_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is for current week' do
            let(:current_week) { Date.current.beginning_of_week(:monday) }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: current_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end
        end

        context 'when some goals have recent check-ins but not all' do
          let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
          let(:recent_week) { cutoff_week }
          let(:confidence_reporter) { create(:person) }
          let!(:goal2) do
            create(:goal,
                   owner: company_teammate,
                   creator: company_teammate,
                   company: company,
                   started_at: 1.day.ago,
                   completed_at: nil)
          end

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: recent_week,
                   confidence_reporter: confidence_reporter)
            # goal2 has no check-ins
          end

          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'when goals have check-ins but all are older than 2 weeks' do
          let(:old_week) { (Date.current - 14.days).beginning_of_week(:monday) - 1.week }
          let(:confidence_reporter) { create(:person) }

          before do
            create(:goal_check_in,
                   goal: goal1,
                   check_in_week_start: old_week,
                   confidence_reporter: confidence_reporter)
          end

          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'when goals have no check-ins at all' do
          it 'returns :yellow' do
            result = helper.goals_status_indicator(company_teammate)
            expect(result).to eq(:yellow)
          end
        end

        context 'week calculation edge cases' do
          let(:confidence_reporter) { create(:person) }

          context 'when check-in is exactly on the cutoff week (14 days ago)' do
            let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: cutoff_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :green' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:green)
            end
          end

          context 'when check-in is one day before cutoff week' do
            let(:cutoff_week) { (Date.current - 14.days).beginning_of_week(:monday) }
            let(:old_week) { cutoff_week - 1.week }

            before do
              goal1.goal_check_ins.destroy_all
              create(:goal_check_in,
                     goal: goal1,
                     check_in_week_start: old_week,
                     confidence_reporter: confidence_reporter)
            end

            it 'returns :yellow' do
              result = helper.goals_status_indicator(company_teammate)
              expect(result).to eq(:yellow)
            end
          end
        end
      end
    end
  end

  describe '#relevant_assignments_for_about_me' do
    let(:organization) { create(:organization, :company) }
    let(:person) { create(:person) }
    let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
    let(:position_type) { create(:position_type, organization: organization) }
    let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let!(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil) }

    context 'when no position exists' do
      before do
        employment_tenure.update!(ended_at: 1.day.ago)
      end

      it 'returns empty collection' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        expect(result).to be_empty
      end
    end

    context 'when position has required assignments' do
      let(:assignment1) { create(:assignment, company: organization) }
      let(:assignment2) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignments using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: actual_position, assignment: assignment2, assignment_type: 'required')
      end

      it 'returns required assignments' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        assignment_ids = result.pluck(:id)
        expect(assignment_ids).to include(assignment1.id, assignment2.id)
        expect(assignment_ids.count).to eq(2)
      end
    end

    context 'when teammate has active assignments with energy > 0' do
      let(:assignment1) { create(:assignment, company: organization) }
      let(:assignment2) { create(:assignment, company: organization) }
      let!(:assignment_tenure1) { create(:assignment_tenure, teammate: teammate, assignment: assignment1, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil) }
      let!(:assignment_tenure2) { create(:assignment_tenure, teammate: teammate, assignment: assignment2, anticipated_energy_percentage: 30, started_at: 1.month.ago, ended_at: nil) }

      it 'returns active assignments with energy > 0' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        expect(result).to include(assignment1, assignment2)
        expect(result.count).to eq(2)
      end
    end

    context 'when teammate has both required and active assignments' do
      let(:required_assignment) { create(:assignment, company: organization) }
      let(:active_assignment) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignment using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: required_assignment, assignment_type: 'required')
        create(:assignment_tenure, teammate: teammate, assignment: active_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
      end

      it 'returns both types of assignments' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        assignment_ids = result.pluck(:id)
        expect(assignment_ids).to include(required_assignment.id, active_assignment.id)
        expect(assignment_ids.count).to eq(2)
      end
    end

    context 'when assignment is both required and active with energy > 0' do
      let(:shared_assignment) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignment using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: shared_assignment, assignment_type: 'required')
        create(:assignment_tenure, teammate: teammate, assignment: shared_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
      end

      it 'includes the assignment only once' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        assignment_ids = result.pluck(:id)
        expect(assignment_ids.count).to eq(1)
        expect(assignment_ids).to include(shared_assignment.id)
      end
    end

    context 'when active assignment has energy = 0' do
      let(:assignment) { create(:assignment, company: organization) }
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 0, started_at: 1.month.ago, ended_at: nil) }

      it 'does not include it' do
        result = helper.relevant_assignments_for_about_me(teammate, organization)
        assignment_ids = result.pluck(:id)
        expect(assignment_ids).not_to include(assignment.id)
      end
    end
  end

  describe '#assignments_check_in_status_indicator' do
    let(:organization) { create(:organization, :company) }
    let(:person) { create(:person) }
    let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
    let(:position_type) { create(:position_type, organization: organization) }
    let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
    let(:position) { create(:position, position_type: position_type, position_level: position_level) }
    let(:employment_tenure) { create(:employment_tenure, teammate: teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil) }

    before do
      employment_tenure
    end

    context 'when no active employment tenure exists' do
      before do
        employment_tenure.update!(ended_at: 1.day.ago)
      end

      it 'returns :yellow' do
        result = helper.assignments_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end

    context 'when position has no required assignments and no active assignments with energy > 0' do
      it 'returns :yellow' do
        result = helper.assignments_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end

    context 'when teammate has never had any assignment check-in finalized' do
      let(:assignment1) { create(:assignment, company: organization) }
      let(:assignment2) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignments using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: actual_position, assignment: assignment2, assignment_type: 'required')
        
        # Create open check-ins (not finalized)
        create(:assignment_check_in,
               teammate: teammate,
               assignment: assignment1,
               employee_completed_at: nil,
               manager_completed_at: nil,
               official_check_in_completed_at: nil)
      end

      it 'returns :yellow even when there are relevant assignments' do
        result = helper.assignments_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end

    context 'when position has required assignments' do
      let(:assignment1) { create(:assignment, company: organization) }
      let(:assignment2) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignments using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: assignment1, assignment_type: 'required')
        create(:position_assignment, position: actual_position, assignment: assignment2, assignment_type: 'required')
      end

      context 'when all required assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :green' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:green)
        end
      end

      context 'when none of the required assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :red' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:red)
        end
      end

      context 'when some required assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :yellow' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:yellow)
        end
      end
    end

    context 'when teammate has active assignments with energy > 0' do
      let(:assignment1) { create(:assignment, company: organization) }
      let(:assignment2) { create(:assignment, company: organization) }
      let!(:assignment_tenure1) { create(:assignment_tenure, teammate: teammate, assignment: assignment1, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil) }
      let!(:assignment_tenure2) { create(:assignment_tenure, teammate: teammate, assignment: assignment2, anticipated_energy_percentage: 30, started_at: 1.month.ago, ended_at: nil) }

      context 'when all active assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :green' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:green)
        end
      end

      context 'when none of the active assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment1,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: assignment2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :red' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:red)
        end
      end
    end

    context 'when teammate has both required assignments and active assignments with energy > 0' do
      let(:required_assignment) { create(:assignment, company: organization) }
      let(:active_assignment) { create(:assignment, company: organization) }

      before do
        # Ensure employment_tenure is set up first
        employment_tenure
        teammate.reload
        
        # Get the actual position from the employment tenure
        actual_position = teammate.active_employment_tenure.position
        
        # Create position assignment using the actual position from the tenure
        create(:position_assignment, position: actual_position, assignment: required_assignment, assignment_type: 'required')
        create(:assignment_tenure, teammate: teammate, assignment: active_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
      end

      context 'when all assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: required_assignment,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: active_assignment,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :green' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:green)
        end
      end

      context 'when some assignments have recent check-ins' do
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: required_assignment,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: active_assignment,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :yellow' do
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:yellow)
        end
      end

      context 'when assignment is both required and active with energy > 0' do
        let(:shared_assignment) { create(:assignment, company: organization) }
        let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
        let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

        before do
          # Ensure employment_tenure is set up first
          employment_tenure
          teammate.reload
          
          # Get the actual position from the employment tenure
          actual_position = teammate.active_employment_tenure.position
          
          # Create position assignment using the actual position from the tenure
          create(:position_assignment, position: actual_position, assignment: shared_assignment, assignment_type: 'required')
          create(:assignment_tenure, teammate: teammate, assignment: shared_assignment, anticipated_energy_percentage: 50, started_at: 1.month.ago, ended_at: nil)
          
          # Create check-ins for ALL relevant assignments (including those from parent context)
          check_in_date = 30.days.ago
          
          # Check-in for required_assignment (from parent context)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: required_assignment,
                 check_in_started_on: check_in_date.to_date,
                 employee_completed_at: check_in_date,
                 manager_completed_at: check_in_date,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: check_in_date,
                 finalized_by_teammate: finalized_by)
          
          # Check-in for active_assignment (from parent context)
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: active_assignment,
                 check_in_started_on: check_in_date.to_date,
                 employee_completed_at: check_in_date,
                 manager_completed_at: check_in_date,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: check_in_date,
                 finalized_by_teammate: finalized_by)
          
          # Check-in for shared_assignment
          create(:assignment_check_in,
                 teammate: teammate,
                 assignment: shared_assignment,
                 check_in_started_on: check_in_date.to_date,
                 employee_completed_at: check_in_date,
                 manager_completed_at: check_in_date,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: check_in_date,
                 finalized_by_teammate: finalized_by)
          
          # Reload to ensure associations are fresh
          teammate.reload
          shared_assignment.reload
        end

        it 'counts the assignment only once and returns :green' do
          # Verify the shared assignment is included only once (not duplicated)
          relevant_assignments = helper.relevant_assignments_for_about_me(teammate, organization)
          assignment_ids = relevant_assignments.pluck(:id)
          expect(assignment_ids.count(shared_assignment.id)).to eq(1)
          
          # Verify we have all 3 assignments (required_assignment, active_assignment, shared_assignment)
          expect(assignment_ids.count).to eq(3)
          
          # Verify all check-ins exist and are recent
          check_in = AssignmentCheckIn.where(teammate: teammate, assignment: shared_assignment).closed.order(official_check_in_completed_at: :desc).first
          expect(check_in).to be_present
          cutoff_date = 90.days.ago
          expect(check_in.official_check_in_completed_at).to be >= cutoff_date
          
          result = helper.assignments_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:green)
        end
      end
    end

    context 'when active assignment has energy = 0' do
      let(:assignment) { create(:assignment, company: organization) }
      let!(:assignment_tenure) { create(:assignment_tenure, teammate: teammate, assignment: assignment, anticipated_energy_percentage: 0, started_at: 1.month.ago, ended_at: nil) }

      it 'does not include it and returns :yellow' do
        result = helper.assignments_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end
  end

  describe '#aspirations_check_in_status_indicator' do
    let(:organization) { create(:organization, :company) }
    let(:person) { create(:person) }
    let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }

    context 'when teammate has never had any aspiration check-in finalized' do
      let!(:aspiration1) { create(:aspiration, organization: organization) }
      let!(:aspiration2) { create(:aspiration, organization: organization) }

      before do
        # Create open check-ins (not finalized)
        create(:aspiration_check_in,
               teammate: teammate,
               aspiration: aspiration1,
               employee_completed_at: nil,
               manager_completed_at: nil,
               official_check_in_completed_at: nil)
      end

      it 'returns :yellow even when there are company aspirations' do
        result = helper.aspirations_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end

    context 'when no company aspirations exist' do
      it 'returns :yellow' do
        result = helper.aspirations_check_in_status_indicator(teammate, organization)
        expect(result).to eq(:yellow)
      end
    end

    context 'when company has aspirations and teammate has finalized check-ins' do
      let!(:aspiration1) { create(:aspiration, organization: organization) }
      let!(:aspiration2) { create(:aspiration, organization: organization) }
      let(:finalized_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }
      let(:manager_completed_by) { CompanyTeammate.create!(person: create(:person), organization: organization) }

      context 'when all aspirations have recent check-ins' do
        before do
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration2,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :green' do
          result = helper.aspirations_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:green)
        end
      end

      context 'when none of the aspirations have recent check-ins' do
        before do
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration1,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :red' do
          result = helper.aspirations_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:red)
        end
      end

      context 'when some aspirations have recent check-ins' do
        before do
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration1,
                 employee_completed_at: 30.days.ago,
                 manager_completed_at: 30.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 30.days.ago,
                 finalized_by_teammate: finalized_by)
          create(:aspiration_check_in,
                 teammate: teammate,
                 aspiration: aspiration2,
                 employee_completed_at: 100.days.ago,
                 manager_completed_at: 100.days.ago,
                 manager_completed_by_teammate: manager_completed_by,
                 official_check_in_completed_at: 100.days.ago,
                 finalized_by_teammate: finalized_by)
        end

        it 'returns :yellow' do
          result = helper.aspirations_check_in_status_indicator(teammate, organization)
          expect(result).to eq(:yellow)
        end
      end
    end
  end
end

