# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentOutcome, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { CompanyTeammate.create!(person: person, organization: organization, can_manage_maap: true) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization)
  end

  it "keeps assignment multisearch current when outcomes change after initial index" do
    assignment = create(
      :assignment,
      company: organization,
      title: "Static Title For Outcome Index",
      tagline: "Static tagline only"
    )
    assignment.update_pg_search_document

    create(
      :assignment_outcome,
      assignment: assignment,
      description: "PostIndex UniqueOutcomeCommitToken target"
    )

    results = GlobalSearchQuery.new(
      query: "UniqueOutcomeCommitToken",
      current_organization: organization,
      current_teammate: teammate
    ).call

    expect(results[:assignments]).to include(assignment)
  end
end
