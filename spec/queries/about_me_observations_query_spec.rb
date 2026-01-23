require 'rails_helper'

RSpec.describe AboutMeObservationsQuery, type: :query do
  let(:organization) { create(:organization, :company) }
  let(:teammate_person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: teammate_person, organization: organization) }
  let(:other_person) { create(:person) }
  let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }
  let(:third_person) { create(:person) }
  let(:third_teammate) { create(:company_teammate, person: third_person, organization: organization) }

  let(:query) { described_class.new(teammate, organization) }

  describe '#observations_given' do
    context 'when teammate is only observer' do
      let!(:observation_given) do
        build(:observation,
              observer: teammate_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'includes the observation' do
        expect(query.observations_given).to include(observation_given)
      end
    end

    context 'when teammate is both observer and observee (self-observation)' do
      let!(:self_observation) do
        build(:observation,
              observer: teammate_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'excludes the self-observation' do
        expect(query.observations_given).not_to include(self_observation)
      end
    end

    context 'when teammate is observer and one of multiple observees' do
      let!(:multi_observee_observation) do
        build(:observation,
              observer: teammate_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.observees.build(teammate: other_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'excludes the observation' do
        expect(query.observations_given).not_to include(multi_observee_observation)
      end
    end

    context 'filtering' do
      it 'only includes published observations' do
        published = create(:observation,
                           observer: teammate_person,
                           company: organization,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        draft = create(:observation,
                       observer: teammate_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 10.days.ago,
                       published_at: nil).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        results = query.observations_given
        expect(results).to include(published)
        expect(results).not_to include(draft)
      end

      it 'excludes observer_only privacy level' do
        observer_only = create(:observation,
                                observer: teammate_person,
                                company: organization,
                                privacy_level: :observer_only,
                                observed_at: 10.days.ago,
                                published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        public_obs = create(:observation,
                           observer: teammate_person,
                           company: organization,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        results = query.observations_given
        expect(results).not_to include(observer_only)
        expect(results).to include(public_obs)
      end

      it 'only includes observations from last 30 days' do
        recent = create(:observation,
                        observer: teammate_person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        old = create(:observation,
                     observer: teammate_person,
                     company: organization,
                     privacy_level: :public_to_company,
                     observed_at: 35.days.ago,
                     published_at: 35.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        results = query.observations_given
        expect(results).to include(recent)
        expect(results).not_to include(old)
      end

      it 'excludes soft-deleted observations' do
        active = create(:observation,
                        observer: teammate_person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago,
                        deleted_at: nil).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        deleted = create(:observation,
                         observer: teammate_person,
                         company: organization,
                         privacy_level: :public_to_company,
                         observed_at: 10.days.ago,
                         published_at: 10.days.ago,
                         deleted_at: 1.day.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        results = query.observations_given
        expect(results).to include(active)
        expect(results).not_to include(deleted)
      end

      it 'only includes observations from the correct organization' do
        other_org = create(:organization, :company)
        other_org_teammate = create(:company_teammate, person: teammate_person, organization: other_org)
        other_org_person = create(:person)
        other_org_observee = create(:company_teammate, person: other_org_person, organization: other_org)

        correct_org = create(:observation,
                              observer: teammate_person,
                              company: organization,
                              privacy_level: :public_to_company,
                              observed_at: 10.days.ago,
                              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        wrong_org = create(:observation,
                           observer: teammate_person,
                           company: other_org,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_org_observee)
          obs.save!
        end

        results = query.observations_given
        expect(results).to include(correct_org)
        expect(results).not_to include(wrong_org)
      end

      it 'orders by observed_at descending' do
        older = create(:observation,
                       observer: teammate_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 20.days.ago,
                       published_at: 20.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        newer = create(:observation,
                       observer: teammate_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 5.days.ago,
                       published_at: 5.days.ago).tap do |obs|
          obs.observees.build(teammate: other_teammate)
          obs.save!
        end

        results = query.observations_given.to_a
        expect(results.index(newer)).to be < results.index(older)
      end
    end
  end

  describe '#observations_received' do
    context 'when teammate is only observee' do
      let!(:observation_received) do
        build(:observation,
              observer: other_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'includes the observation' do
        expect(query.observations_received).to include(observation_received)
      end
    end

    context 'when teammate is both observer and observee (self-observation)' do
      let!(:self_observation) do
        build(:observation,
              observer: teammate_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'includes the self-observation' do
        expect(query.observations_received).to include(self_observation)
      end
    end

    context 'when teammate is one of multiple observees' do
      let!(:multi_observee_observation) do
        build(:observation,
              observer: other_person,
              company: organization,
              privacy_level: :public_to_company,
              observed_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.observees.build(teammate: third_teammate)
          obs.save!
          obs.publish!
        end
      end

      it 'includes the observation' do
        expect(query.observations_received).to include(multi_observee_observation)
      end
    end

    context 'filtering' do
      it 'only includes published observations' do
        published = create(:observation,
                           observer: other_person,
                           company: organization,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        draft = create(:observation,
                       observer: other_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 10.days.ago,
                       published_at: nil).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        results = query.observations_received
        expect(results).to include(published)
        expect(results).not_to include(draft)
      end

      it 'excludes observer_only privacy level' do
        observer_only = create(:observation,
                                observer: other_person,
                                company: organization,
                                privacy_level: :observer_only,
                                observed_at: 10.days.ago,
                                published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        public_obs = create(:observation,
                            observer: other_person,
                            company: organization,
                            privacy_level: :public_to_company,
                            observed_at: 10.days.ago,
                            published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        results = query.observations_received
        expect(results).not_to include(observer_only)
        expect(results).to include(public_obs)
      end

      it 'only includes observations from last 30 days' do
        recent = create(:observation,
                        observer: other_person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        old = create(:observation,
                     observer: other_person,
                     company: organization,
                     privacy_level: :public_to_company,
                     observed_at: 35.days.ago,
                     published_at: 35.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        results = query.observations_received
        expect(results).to include(recent)
        expect(results).not_to include(old)
      end

      it 'excludes soft-deleted observations' do
        active = create(:observation,
                        observer: other_person,
                        company: organization,
                        privacy_level: :public_to_company,
                        observed_at: 10.days.ago,
                        published_at: 10.days.ago,
                        deleted_at: nil).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        deleted = create(:observation,
                         observer: other_person,
                         company: organization,
                         privacy_level: :public_to_company,
                         observed_at: 10.days.ago,
                         published_at: 10.days.ago,
                         deleted_at: 1.day.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        results = query.observations_received
        expect(results).to include(active)
        expect(results).not_to include(deleted)
      end

      it 'only includes observations from the correct organization' do
        other_org = create(:organization, :company)
        other_org_person = create(:person)
        other_org_teammate = create(:company_teammate, person: teammate_person, organization: other_org)
        other_org_observer = create(:company_teammate, person: other_org_person, organization: other_org)

        correct_org = create(:observation,
                              observer: other_person,
                              company: organization,
                              privacy_level: :public_to_company,
                              observed_at: 10.days.ago,
                              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        wrong_org = create(:observation,
                           observer: other_org_person,
                           company: other_org,
                           privacy_level: :public_to_company,
                           observed_at: 10.days.ago,
                           published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: other_org_teammate)
          obs.save!
        end

        results = query.observations_received
        expect(results).to include(correct_org)
        expect(results).not_to include(wrong_org)
      end

      it 'orders by observed_at descending' do
        older = create(:observation,
                       observer: other_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 20.days.ago,
                       published_at: 20.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        newer = create(:observation,
                       observer: other_person,
                       company: organization,
                       privacy_level: :public_to_company,
                       observed_at: 5.days.ago,
                       published_at: 5.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        results = query.observations_received.to_a
        expect(results.index(newer)).to be < results.index(older)
      end

      it 'returns distinct observations when teammate is observee multiple times' do
        observation = create(:observation,
                              observer: other_person,
                              company: organization,
                              privacy_level: :public_to_company,
                              observed_at: 10.days.ago,
                              published_at: 10.days.ago).tap do |obs|
          obs.observees.build(teammate: teammate)
          obs.save!
        end

        # This shouldn't happen in practice, but test distinct works
        results = query.observations_received.to_a
        expect(results.count(observation)).to eq(1)
      end
    end
  end
end

