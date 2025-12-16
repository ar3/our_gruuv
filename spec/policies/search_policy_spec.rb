require 'rails_helper'

RSpec.describe SearchPolicy, type: :policy do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization) }
  let(:pundit_user) { OpenStruct.new(user: teammate, impersonating_teammate: nil) }
  let(:policy) { SearchPolicy.new(pundit_user, :search) }

end
