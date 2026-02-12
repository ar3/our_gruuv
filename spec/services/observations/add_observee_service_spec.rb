require 'rails_helper'

RSpec.describe Observations::AddObserveeService, type: :service do
  let(:company) { create(:organization, :company) }
  let(:other_company) { create(:organization, :company) }
  let(:observer) { create(:person) }
  let(:teammate) { create(:teammate, organization: company) }
  let(:observation) do
    Observation.create!(
      observer: observer,
      company: company,
      story: 'Test observation',
      privacy_level: :observed_only,
      observed_at: Time.current
    )
  end

  describe '#call' do
    context 'when observee has active assignments with given energy' do
      let(:assignment1) { create(:assignment, company: company) }
      let(:assignment2) { create(:assignment, company: company) }
      let!(:active_tenure1) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment1,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end
      let!(:active_tenure2) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment2,
               started_at: 2.months.ago,
               ended_at: nil,
               anticipated_energy_percentage: 30)
      end

      it 'creates the observee' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observees.count }.by(1)
        expect(observation.observees.exists?(teammate_id: teammate.id)).to be true
      end

      it 'creates observation ratings with na rating for each active assignment' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(2)

        rating1 = observation.observation_ratings.find_by(rateable: assignment1)
        rating2 = observation.observation_ratings.find_by(rateable: assignment2)

        expect(rating1).to be_present
        expect(rating1.rating).to eq('na')
        expect(rating2).to be_present
        expect(rating2.rating).to eq('na')
      end

      it 'returns the created observee' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        observee = service.call
        expect(observee).to be_a(Observee)
        expect(observee.teammate.id).to eq(teammate.id)
        expect(observee.observation).to eq(observation)
      end
    end

    context 'when assignment already has a rating' do
      let(:assignment) { create(:assignment, company: company) }
      let!(:active_tenure) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end
      let!(:existing_rating) do
        create(:observation_rating,
               observation: observation,
               rateable: assignment,
               rating: :strongly_agree)
      end

      it 'preserves the existing rating' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.not_to change { observation.observation_ratings.count }

        rating = observation.observation_ratings.find_by(rateable: assignment)
        expect(rating.rating).to eq('strongly_agree')
        expect(rating.id).to eq(existing_rating.id)
      end
    end

    context 'when assignment has no energy (0%)' do
      let(:assignment_with_energy) { create(:assignment, company: company) }
      let(:assignment_without_energy) { create(:assignment, company: company) }
      let!(:tenure_with_energy) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment_with_energy,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end
      let!(:tenure_without_energy) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment_without_energy,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 0)
      end

      it 'only adds assignments with given energy > 0' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(1)

        expect(observation.observation_ratings.exists?(rateable: assignment_with_energy)).to be true
        expect(observation.observation_ratings.exists?(rateable: assignment_without_energy)).to be false
      end
    end

    context 'when assignment is inactive' do
      let(:active_assignment) { create(:assignment, company: company) }
      let(:inactive_assignment) { create(:assignment, company: company) }
      let!(:active_tenure) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: active_assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end
      let!(:inactive_tenure) do
        create(:assignment_tenure,
               :inactive,
               teammate: teammate,
               assignment: inactive_assignment,
               started_at: 3.months.ago,
               ended_at: 1.month.ago,
               anticipated_energy_percentage: 50)
      end

      it 'only adds active assignments' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(1)

        expect(observation.observation_ratings.exists?(rateable: active_assignment)).to be true
        expect(observation.observation_ratings.exists?(rateable: inactive_assignment)).to be false
      end
    end

    context 'when assignment belongs to different company' do
      let(:company_assignment) { create(:assignment, company: company) }
      let(:other_company_assignment) { create(:assignment, company: other_company) }
      let!(:company_tenure) do
        create(:assignment_tenure,
               teammate: teammate,
               assignment: company_assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end
      let!(:other_company_tenure) do
        other_teammate = create(:teammate, organization: other_company, person: teammate.person)
        create(:assignment_tenure,
               teammate: other_teammate,
               assignment: other_company_assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end

      it 'only adds assignments from the observation company' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(1)

        expect(observation.observation_ratings.exists?(rateable: company_assignment)).to be true
        expect(observation.observation_ratings.exists?(rateable: other_company_assignment)).to be false
      end
    end

    context 'when observee has no active assignments' do
      it 'creates the observee without adding any ratings' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observees.count }.by(1)
        expect { service.call }.not_to change { observation.observation_ratings.count }
      end
    end

    context 'when observee has position with direct milestone requirements (position_abilities)' do
      let(:title) { create(:title, company: company) }
      let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
      let(:position_with_direct_milestones) { create(:position, title: title, position_level: position_level) }
      let(:ability_from_position) { create(:ability, company: company) }
      let!(:position_ability) do
        create(:position_ability, position: position_with_direct_milestones, ability: ability_from_position, milestone_level: 2)
      end
      let!(:employment_tenure) do
        et = create(:employment_tenure, company_teammate: teammate, company: company, started_at: 1.year.ago, ended_at: nil)
        et.update!(position: position_with_direct_milestones)
        et
      end

      it 'adds ability ratings for position direct milestone abilities' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.where(rateable_type: 'Ability').count }.by(1)

        rating = observation.observation_ratings.find_by(rateable_type: 'Ability', rateable_id: ability_from_position.id)
        expect(rating).to be_present
        expect(rating.rating).to eq('na')
      end
    end

    context 'when observee has required assignments with ability milestones' do
      let(:title) { create(:title, company: company) }
      let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
      let(:position_with_required) { create(:position, title: title, position_level: position_level) }
      let(:required_assignment) { create(:assignment, company: company) }
      let(:ability_from_assignment) { create(:ability, company: company) }
      let!(:assignment_ability) do
        create(:assignment_ability, assignment: required_assignment, ability: ability_from_assignment, milestone_level: 1)
      end
      let!(:position_assignment) do
        create(:position_assignment, position: position_with_required, assignment: required_assignment, assignment_type: 'required')
      end
      let!(:employment_tenure) do
        et = create(:employment_tenure, company_teammate: teammate, company: company, started_at: 1.year.ago, ended_at: nil)
        et.update!(position: position_with_required)
        et
      end

      it 'adds ability ratings for abilities from required assignments' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.where(rateable_type: 'Ability').count }.by(1)

        rating = observation.observation_ratings.find_by(rateable_type: 'Ability', rateable_id: ability_from_assignment.id)
        expect(rating).to be_present
        expect(rating.rating).to eq('na')
      end
    end

    context 'when observee already exists' do
      let!(:existing_observee) { create(:observee, observation: observation, teammate: teammate) }

      it 'returns the existing observee without creating a duplicate' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.not_to change { observation.observees.count }
        expect(service.call).to eq(existing_observee)
      end

      it 'still adds active assignments if they are not already rated' do
        assignment = create(:assignment, company: company)
        create(:assignment_tenure,
               teammate: teammate,
               assignment: assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)

        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(1)
      end
    end

    context 'with multiple active assignments' do
      let(:assignments) { create_list(:assignment, 3, company: company) }
      let!(:tenures) do
        assignments.map do |assignment|
          create(:assignment_tenure,
                 teammate: teammate,
                 assignment: assignment,
                 started_at: 1.month.ago,
                 ended_at: nil,
                 anticipated_energy_percentage: rand(10..100))
        end
      end

      it 'adds all active assignments with given energy' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(3)

        assignments.each do |assignment|
          rating = observation.observation_ratings.find_by(rateable: assignment)
          expect(rating).to be_present
          expect(rating.rating).to eq('na')
        end
      end
    end

    context 'with mixed scenario' do
      let(:active_with_energy) { create(:assignment, company: company) }
      let(:active_without_energy) { create(:assignment, company: company) }
      let(:inactive_with_energy) { create(:assignment, company: company) }
      let(:already_rated) { create(:assignment, company: company) }
      let(:other_company_assignment) { create(:assignment, company: other_company) }

      before do
        # Active with energy - should be added
        create(:assignment_tenure,
               teammate: teammate,
               assignment: active_with_energy,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)

        # Active without energy - should NOT be added
        create(:assignment_tenure,
               teammate: teammate,
               assignment: active_without_energy,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 0)

        # Inactive with energy - should NOT be added
        create(:assignment_tenure,
               :inactive,
               teammate: teammate,
               assignment: inactive_with_energy,
               started_at: 3.months.ago,
               ended_at: 1.month.ago,
               anticipated_energy_percentage: 50)

        # Already rated - should NOT be added (preserve existing)
        create(:assignment_tenure,
               teammate: teammate,
               assignment: already_rated,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
        create(:observation_rating,
               observation: observation,
               rateable: already_rated,
               rating: :agree)

        # Other company - should NOT be added
        other_teammate = create(:teammate, organization: other_company, person: teammate.person)
        create(:assignment_tenure,
               teammate: other_teammate,
               assignment: other_company_assignment,
               started_at: 1.month.ago,
               ended_at: nil,
               anticipated_energy_percentage: 50)
      end

      it 'only adds the active assignment with given energy from the same company' do
        service = described_class.new(observation: observation, teammate_id: teammate.id)
        expect { service.call }.to change { observation.observation_ratings.count }.by(1)

        expect(observation.observation_ratings.exists?(rateable: active_with_energy)).to be true
        expect(observation.observation_ratings.exists?(rateable: active_without_energy)).to be false
        expect(observation.observation_ratings.exists?(rateable: inactive_with_energy)).to be false
        expect(observation.observation_ratings.exists?(rateable: already_rated)).to be true
        expect(observation.observation_ratings.find_by(rateable: already_rated).rating).to eq('agree')
        expect(observation.observation_ratings.exists?(rateable: other_company_assignment)).to be false
      end
    end
  end
end

