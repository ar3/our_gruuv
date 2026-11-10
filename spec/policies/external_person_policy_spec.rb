# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExternalPersonPolicy, type: :policy do
  subject { described_class }

  let(:company) { create(:organization, :company) }
  let(:viewer_teammate) { create(:company_teammate, organization: company) }
  let(:external_person) { create(:person) }
  let(:pundit_user) { OpenStruct.new(user: viewer_teammate, impersonating_teammate: nil) }

  permissions :show? do
    it 'allows an org teammate to view an external person' do
      expect(subject).to permit(pundit_user, external_person)
    end

    it 'denies viewing someone who is an active teammate of the org' do
      expect(subject).not_to permit(pundit_user, viewer_teammate.person)
    end

    it 'denies viewing someone who only has a terminated teammate record' do
      former = create(:person)
      create(:company_teammate,
        person: former,
        organization: company,
        last_terminated_at: Date.current,
        first_employed_at: 1.year.ago
      )
      expect(subject).not_to permit(pundit_user, former)
    end

    it 'denies when there is no viewing teammate' do
      expect(subject).not_to permit(OpenStruct.new(user: nil, impersonating_teammate: nil), external_person)
    end
  end
end
