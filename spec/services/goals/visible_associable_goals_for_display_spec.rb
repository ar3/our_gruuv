# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::VisibleAssociableGoalsForDisplay do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:viewer_person) { create(:person) }
  let!(:viewer_teammate) { create(:company_teammate, person: viewer_person, organization: organization) }
  let(:subject_person) { create(:person) }
  let!(:subject_teammate) { create(:company_teammate, person: subject_person, organization: organization) }
  let(:other_person) { create(:person) }
  let!(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }
  let(:goals_scope) { Goal.where(company_id: organization.id) }

  def call(subject_teammate: nil)
    described_class.new(
      associable: assignment,
      viewer: viewer_person,
      goals_scope: goals_scope,
      subject_teammate: subject_teammate
    ).call
  end

  describe "privacy filtering" do
    let!(:subject_goal) do
      create(:goal, :only_creator_and_owner,
        company_id: organization.id,
        creator: subject_teammate,
        owner: subject_teammate,
        title: "Subject private goal")
    end
    let!(:other_goal) do
      create(:goal, :only_creator_and_owner,
        company_id: organization.id,
        creator: other_teammate,
        owner: other_teammate,
        title: "Other private goal")
    end

    before do
      create(:goal_association, associable: assignment, goal: subject_goal)
      create(:goal_association, associable: assignment, goal: other_goal)
    end

    it "excludes goals the viewer cannot see" do
      result = call
      titles = result[:goals].map(&:title)
      expect(titles).not_to include("Other private goal")
    end

    it "includes goals owned by the subject when viewer is their manager and privacy allows managers" do
      subject_goal.update!(privacy_level: "only_creator_owner_and_managers")
      create(:employment_tenure,
        teammate: subject_teammate,
        company: organization,
        manager_teammate: viewer_teammate)

      result = call(subject_teammate: subject_teammate)
      expect(result[:goals].map(&:title)).to contain_exactly("Subject private goal")
    end

    it "on teammate lens, excludes another teammate's goals even when viewer could see them elsewhere" do
      public_other_goal = create(:goal, :everyone_in_company,
        company_id: organization.id,
        creator: other_teammate,
        owner: other_teammate,
        title: "Other public goal")
      create(:goal_association, associable: assignment, goal: public_other_goal)

      result = call(subject_teammate: subject_teammate)
      titles = result[:goals].map(&:title)
      expect(titles).not_to include("Other public goal")
    end
  end
end
