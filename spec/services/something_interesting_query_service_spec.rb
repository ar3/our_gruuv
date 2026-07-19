require 'rails_helper'

RSpec.describe SomethingInterestingQueryService do
  let(:company) { create(:organization) }
  let(:viewer_person) { create(:person) }
  let(:viewer) { create(:company_teammate, person: viewer_person, organization: company) }
  let(:since) { 2.days.ago }

  subject(:service) { described_class.new(teammate: viewer, since: since) }

  def make_old(record)
    record.update_column(:updated_at, 3.days.ago)
    record
  end

  describe '#goals_updated_by_those_i_serve' do
    let(:report) { create(:company_teammate, organization: company) }
    let!(:tenure) { create(:employment_tenure, company_teammate: report, company: company, manager: viewer) }

    it 'includes recently updated goals owned by direct reports' do
      goal = create(:goal, owner: report, creator: report, company: company)

      results = service.goals_updated_by_those_i_serve

      expect(results.map { |a| a.goal }).to include(goal)
    end

    it 'excludes goals not updated since the baseline' do
      goal = create(:goal, owner: report, creator: report, company: company)
      make_old(goal)

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).not_to include(goal)
    end

    it 'includes stale goals that got a new check-in from someone else' do
      goal = create(:goal, owner: report, creator: report, company: company)
      check_in = create(:goal_check_in, goal: goal, confidence_reporter: report.person)
      make_old(goal)

      results = service.goals_updated_by_those_i_serve
      activity = results.find { |a| a.goal == goal }

      expect(activity).to be_present
      expect(activity.new_check_ins).to eq([check_in])
      expect(activity.record_updated).to be(false)
    end

    it 'excludes goals whose only new check-in came from the viewer' do
      goal = create(:goal, owner: report, creator: report, company: company)
      create(:goal_check_in, goal: goal, confidence_reporter: viewer_person)
      make_old(goal)

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).not_to include(goal)
    end

    it 'excludes goals owned by teammates the viewer does not manage' do
      stranger = create(:company_teammate, organization: company)
      goal = create(:goal, owner: stranger, creator: stranger, company: company)

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).not_to include(goal)
    end

    it 'excludes goals the viewer cannot see' do
      goal = create(:goal, owner: report, creator: report, company: company, privacy_level: 'only_creator')

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).not_to include(goal)
    end

    it 'excludes goal record updates attributable only to the viewer via PaperTrail' do
      goal = create(:goal, owner: report, creator: report, company: company)
      PaperTrail::Version.where(item_type: 'Goal', item_id: goal.id).delete_all
      PaperTrail::Version.create!(item_type: 'Goal', item_id: goal.id, event: 'update', whodunnit: viewer.id.to_s, created_at: 1.hour.ago)

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).not_to include(goal)
    end

    it 'includes goal record updates attributed to someone else via PaperTrail' do
      goal = create(:goal, owner: report, creator: report, company: company)
      PaperTrail::Version.create!(item_type: 'Goal', item_id: goal.id, event: 'update', whodunnit: report.id.to_s, created_at: 1.hour.ago)

      expect(service.goals_updated_by_those_i_serve.map(&:goal)).to include(goal)
    end
  end

  describe '#goals_updated_on_my_teams' do
    let(:team) { create(:team, company: company) }
    let(:creator) { create(:company_teammate, organization: company) }

    before { create(:team_member, team: team, company_teammate: viewer) }

    it 'includes recently updated goals owned by teams the viewer is on' do
      goal = create(:goal, owner: team, creator: creator, company: company, privacy_level: 'everyone_in_company')

      expect(service.goals_updated_on_my_teams.map(&:goal)).to include(goal)
    end

    it 'excludes goals owned by other teams' do
      other_team = create(:team, company: company)
      goal = create(:goal, owner: other_team, creator: creator, company: company, privacy_level: 'everyone_in_company')

      expect(service.goals_updated_on_my_teams.map(&:goal)).not_to include(goal)
    end
  end

  describe '#assignments_updated' do
    it 'includes recently updated assignments the viewer holds via active tenure' do
      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20)

      expect(service.assignments_updated).to include(assignment)
    end

    it 'excludes held assignments not updated since the baseline' do
      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20)
      make_old(assignment)

      expect(service.assignments_updated).not_to include(assignment)
    end

    it 'includes recently updated assignments on the viewer position' do
      employment = create(:employment_tenure, company_teammate: viewer, company: company)
      assignment = create(:assignment, company: company)
      create(:position_assignment, position: employment.position, assignment: assignment)

      expect(service.assignments_updated).to include(assignment)
    end

    it 'excludes assignments the viewer is not connected to' do
      assignment = create(:assignment, company: company)

      expect(service.assignments_updated).not_to include(assignment)
    end

    it 'excludes assignments from ended tenures' do
      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20, started_at: 1.month.ago, ended_at: 1.week.ago)

      expect(service.assignments_updated).not_to include(assignment)
    end

    it 'excludes assignment updates attributable only to the viewer via PaperTrail' do
      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20)
      PaperTrail::Version.where(item_type: 'Assignment', item_id: assignment.id).delete_all
      PaperTrail::Version.create!(item_type: 'Assignment', item_id: assignment.id, event: 'update', whodunnit: viewer.id.to_s, created_at: 1.hour.ago)

      expect(service.assignments_updated).not_to include(assignment)
    end
  end

  describe '#abilities_updated' do
    it 'includes recently updated abilities attached to held assignments' do
      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20)
      ability = create(:ability, company: company)
      create(:assignment_ability, assignment: assignment, ability: ability)

      expect(service.abilities_updated).to include(ability)
    end

    it 'includes recently updated abilities where the viewer has a milestone' do
      ability = create(:ability, company: company)
      create(:teammate_milestone, company_teammate: viewer, ability: ability)

      expect(service.abilities_updated).to include(ability)
    end

    it 'excludes abilities the viewer is not connected to' do
      ability = create(:ability, company: company)

      expect(service.abilities_updated).not_to include(ability)
    end

    it 'excludes connected abilities not updated since the baseline' do
      ability = create(:ability, company: company)
      create(:teammate_milestone, company_teammate: viewer, ability: ability)
      make_old(ability)

      expect(service.abilities_updated).not_to include(ability)
    end
  end

  describe 'observation sections' do
    let(:report) { create(:company_teammate, organization: company) }
    let(:observer_person) { create(:person) }
    let!(:tenure) { create(:employment_tenure, company_teammate: report, company: company, manager: viewer) }

    def observation_about(teammate, observer:, published_at: 1.hour.ago, privacy_level: :observed_and_managers)
      observation = create(:observation, observer: observer, company: company, published_at: published_at, privacy_level: privacy_level)
      observation.observees.destroy_all
      observation.observees.create!(teammate: teammate)
      observation
    end

    describe '#observations_about_those_i_serve' do
      it 'includes recently published observations about direct reports' do
        observation = observation_about(report, observer: observer_person)

        expect(service.observations_about_those_i_serve).to include(observation)
      end

      it 'excludes observations published before the baseline' do
        observation = observation_about(report, observer: observer_person, published_at: 3.days.ago)

        expect(service.observations_about_those_i_serve).not_to include(observation)
      end

      it 'excludes observations made by the viewer' do
        observation = observation_about(report, observer: viewer_person)

        expect(service.observations_about_those_i_serve).not_to include(observation)
      end

      it 'excludes unpublished observations' do
        observation = observation_about(report, observer: observer_person, published_at: nil)

        expect(service.observations_about_those_i_serve).not_to include(observation)
      end

      it 'excludes observations the viewer cannot see' do
        observation = observation_about(report, observer: observer_person, privacy_level: :observed_only)

        expect(service.observations_about_those_i_serve).not_to include(observation)
      end
    end

    describe '#observations_about_me' do
      it 'includes recently published observations about the viewer' do
        observation = observation_about(viewer, observer: observer_person, privacy_level: :observed_only)

        expect(service.observations_about_me).to include(observation)
      end

      it 'excludes observations about other people' do
        observation = observation_about(report, observer: observer_person, privacy_level: :observed_only)

        expect(service.observations_about_me).not_to include(observation)
      end
    end

    describe '#observation_comments' do
      it 'includes comments on observations where the viewer is an observee' do
        observation = observation_about(viewer, observer: observer_person, privacy_level: :observed_only)
        comment = create(:comment, organization: company, creator: observer_person, commentable: observation, body: 'Clarifying question')

        expect(service.observation_comments).to include(comment)
      end

      it 'includes comments on observations the viewer authored' do
        observation = observation_about(report, observer: viewer_person, privacy_level: :public_to_company)
        commenter = create(:person)
        create(:company_teammate, person: commenter, organization: company)
        comment = create(:comment, organization: company, creator: commenter, commentable: observation)

        expect(service.observation_comments).to include(comment)
      end

      it 'includes comments when the viewer previously commented' do
        other = create(:company_teammate, organization: company)
        observation = observation_about(other, observer: observer_person, privacy_level: :public_to_company)
        create(:comment, organization: company, creator: viewer_person, commentable: observation, body: 'I was here')
        later = create(:comment, organization: company, creator: observer_person, commentable: observation, body: 'Follow-up')

        expect(service.observation_comments).to include(later)
      end

      it 'excludes the viewer\'s own comments' do
        observation = observation_about(viewer, observer: observer_person, privacy_level: :observed_only)
        comment = create(:comment, organization: company, creator: viewer_person, commentable: observation)

        expect(service.observation_comments).not_to include(comment)
      end

      it 'excludes comments before the baseline' do
        observation = observation_about(viewer, observer: observer_person, privacy_level: :observed_only)
        comment = create(:comment, organization: company, creator: observer_person, commentable: observation)
        comment.update_column(:created_at, 3.days.ago)

        expect(service.observation_comments).not_to include(comment)
      end
    end
  end

  describe '#total_count' do
    it 'sums all sections' do
      report = create(:company_teammate, organization: company)
      create(:employment_tenure, company_teammate: report, company: company, manager: viewer)
      create(:goal, owner: report, creator: report, company: company)

      assignment = create(:assignment, company: company)
      create(:assignment_tenure, teammate: viewer, assignment: assignment, anticipated_energy_percentage: 20)

      expect(service.total_count).to eq(2)
    end

    it 'returns zero when nothing has happened' do
      expect(service.total_count).to eq(0)
    end
  end
end
