require 'rails_helper'

RSpec.describe Observations::SyncObserveeRateablesService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:observation) do
    Observation.create!(
      observer: observer,
      company: company,
      story: 'Test observation',
      privacy_level: :observed_only,
      observed_at: Time.current
    )
  end

  let(:shared_assignment) { create(:assignment, company: company) }
  let(:alex_only_assignment) { create(:assignment, company: company) }
  let(:jordan_only_assignment) { create(:assignment, company: company) }

  let(:shared_ability) { create(:ability, company: company) }
  let(:alex_only_ability) { create(:ability, company: company) }
  let(:jordan_only_ability) { create(:ability, company: company) }

  let(:alex) { create(:teammate, organization: company) }
  let(:jordan) { create(:teammate, organization: company) }

  def give_assignment(teammate, assignment)
    create(:assignment_tenure,
           teammate: teammate,
           assignment: assignment,
           started_at: 1.month.ago,
           ended_at: nil,
           anticipated_energy_percentage: 50)
  end

  def link_ability(assignment, ability)
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
  end

  before do
    link_ability(shared_assignment, shared_ability)
    link_ability(alex_only_assignment, alex_only_ability)
    link_ability(jordan_only_assignment, jordan_only_ability)

    give_assignment(alex, shared_assignment)
    give_assignment(alex, alex_only_assignment)
    give_assignment(jordan, shared_assignment)
    give_assignment(jordan, jordan_only_assignment)

    create(:observee, observation: observation, teammate: alex)
    create(:observee, observation: observation, teammate: jordan)
  end

  describe '#call' do
    it 'keeps only assignments and abilities shared by every observee' do
      described_class.new(observation: observation).call

      expect(observation.observation_ratings.where(rateable_type: 'Assignment').pluck(:rateable_id))
        .to contain_exactly(shared_assignment.id)
      expect(observation.observation_ratings.where(rateable_type: 'Ability').pluck(:rateable_id))
        .to contain_exactly(shared_ability.id)
    end

    it 'leaves rating sections empty when observees share nothing' do
      # Make sets disjoint: remove shared tenures so only unique assignments remain
      alex.assignment_tenures.where(assignment: shared_assignment).destroy_all
      jordan.assignment_tenures.where(assignment: shared_assignment).destroy_all

      described_class.new(observation: observation).call

      expect(observation.observation_ratings.where(rateable_type: %w[Assignment Ability])).to be_empty
    end

    it 'preserves already-scored ratings even when not shared' do
      scored = create(:observation_rating,
                      observation: observation,
                      rateable: alex_only_assignment,
                      rating: :agree)
      create(:observation_rating,
             observation: observation,
             rateable: jordan_only_assignment,
             rating: :na)

      described_class.new(observation: observation).call

      expect(observation.observation_ratings.find_by(id: scored.id).rating).to eq('agree')
      expect(observation.observation_ratings.exists?(rateable: jordan_only_assignment)).to be false
      expect(observation.observation_ratings.exists?(rateable: shared_assignment)).to be true
    end

    it 'does not remove existing aspiration ratings and ensures company values' do
      aspiration = create(:aspiration, company: company, department_id: nil)
      create(:observation_rating, observation: observation, rateable: aspiration, rating: :agree)

      described_class.new(observation: observation).call

      expect(observation.observation_ratings.find_by(rateable: aspiration).rating).to eq('agree')
    end

    it 'restores a remaining observee full set after the other is removed' do
      described_class.new(observation: observation).call
      observation.observees.where(teammate_id: jordan.id).destroy_all

      described_class.new(observation: observation).call

      assignment_ids = observation.observation_ratings.where(rateable_type: 'Assignment').pluck(:rateable_id)
      expect(assignment_ids).to contain_exactly(shared_assignment.id, alex_only_assignment.id)
    end

    context 'when observation is not persisted' do
      let(:unsaved) do
        Observation.new(
          observer: observer,
          company: company,
          story: 'Draft',
          privacy_level: :observed_only,
          observed_at: Time.current
        )
      end

      it 'builds only shared rateables in memory' do
        unsaved.observees.build(teammate_id: alex.id)
        unsaved.observees.build(teammate_id: jordan.id)

        described_class.new(observation: unsaved).call

        assignment_ids = unsaved.observation_ratings.select { |r| r.rateable_type == 'Assignment' }.map(&:rateable_id)
        ability_ids = unsaved.observation_ratings.select { |r| r.rateable_type == 'Ability' }.map(&:rateable_id)

        expect(assignment_ids).to contain_exactly(shared_assignment.id)
        expect(ability_ids).to contain_exactly(shared_ability.id)
      end
    end
  end
end
