# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TeamPolicy, type: :policy do
  subject { described_class }

  let(:company) { create(:organization) }
  let(:team) { create(:team, company: company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: company, first_employed_at: 1.year.ago) }
  let(:manager_teammate) do
    create(:company_teammate, person: create(:person), organization: company,
           first_employed_at: 1.year.ago, can_manage_departments_and_teams: true)
  end
  let(:team_member_teammate) do
    tm = create(:company_teammate, person: create(:person), organization: company, first_employed_at: 1.year.ago)
    create(:team_member, team: team, company_teammate: tm)
    tm
  end

  let(:pundit_user) { OpenStruct.new(user: teammate, impersonating_teammate: nil) }
  let(:pundit_user_manager) { OpenStruct.new(user: manager_teammate, impersonating_teammate: nil) }
  let(:pundit_user_team_member) { OpenStruct.new(user: team_member_teammate, impersonating_teammate: nil) }

  permissions :show? do
    it 'allows teammate in company to view team' do
      expect(subject).to permit(pundit_user, team)
    end

    it 'allows class-level check when teammate is in an organization (e.g. nav link)' do
      expect(subject).to permit(pundit_user, Team)
    end

    it 'denies when teammate is in different organization' do
      other_company = create(:organization, name: 'Other')
      other_teammate = create(:company_teammate, person: create(:person), organization: other_company)
      pundit_other = OpenStruct.new(user: other_teammate, impersonating_teammate: nil)
      expect(subject).not_to permit(pundit_other, team)
    end
  end

  permissions :update? do
    it 'allows teammate with can_manage_departments_and_teams' do
      expect(subject).to permit(pundit_user_manager, team)
    end

    it 'allows team member to update team' do
      expect(subject).to permit(pundit_user_team_member, team)
    end

    it 'denies regular teammate (not manager, not team member)' do
      expect(subject).not_to permit(pundit_user, team)
    end
  end

  permissions :create? do
    it 'allows teammate with can_manage_departments_and_teams' do
      expect(subject).to permit(pundit_user_manager, Team.new(company: company))
    end

    it 'denies regular teammate' do
      expect(subject).not_to permit(pundit_user, Team.new(company: company))
    end
  end

  permissions :archive? do
    it 'allows teammate with can_manage_departments_and_teams' do
      expect(subject).to permit(pundit_user_manager, team)
    end

    it 'denies team member (only update, not archive)' do
      expect(subject).not_to permit(pundit_user_team_member, team)
    end
  end
end
