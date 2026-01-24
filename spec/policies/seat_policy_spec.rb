require 'rails_helper'
require 'ostruct'

RSpec.describe SeatPolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:title) { create(:title, organization: organization) }
  let(:seat) { create(:seat, title: title) }
  
  let(:maap_manager_person) { create(:person) }
  let(:active_employee_person) { create(:person) }
  let(:external_user_person) { create(:person) }
  
  let(:maap_manager_teammate) { CompanyTeammate.create!(person: maap_manager_person, organization: organization, can_manage_maap: true, first_employed_at: 1.year.ago) }
  let(:active_employee_teammate) { CompanyTeammate.create!(person: active_employee_person, organization: organization, can_manage_maap: false, first_employed_at: 1.year.ago) }
  let(:external_user_teammate) { CompanyTeammate.create!(person: external_user_person, organization: organization, can_manage_maap: false) }

  let(:pundit_user_maap_manager) { OpenStruct.new(user: maap_manager_teammate, impersonating_teammate: nil) }
  let(:pundit_user_active_employee) { OpenStruct.new(user: active_employee_teammate, impersonating_teammate: nil) }
  let(:pundit_user_external_user) { OpenStruct.new(user: external_user_teammate, impersonating_teammate: nil) }

  permissions :show? do
    it "allows active employees to view seats" do
      expect(subject).to permit(pundit_user_active_employee, seat)
    end

    it "allows MAAP managers to view seats" do
      expect(subject).to permit(pundit_user_maap_manager, seat)
    end

    it "denies external users" do
      expect(subject).not_to permit(pundit_user_external_user, seat)
    end
  end

  permissions :create? do
    it "allows MAAP managers to create seats" do
      expect(subject).to permit(pundit_user_maap_manager, Seat)
    end

    it "denies active employees from creating seats" do
      expect(subject).not_to permit(pundit_user_active_employee, Seat)
    end

    it "denies external users from creating seats" do
      expect(subject).not_to permit(pundit_user_external_user, Seat)
    end
  end

  permissions :update? do
    it "allows MAAP managers to update seats" do
      expect(subject).to permit(pundit_user_maap_manager, seat)
    end

    it "denies active employees from updating seats" do
      expect(subject).not_to permit(pundit_user_active_employee, seat)
    end

    it "denies external users from updating seats" do
      expect(subject).not_to permit(pundit_user_external_user, seat)
    end
  end

  permissions :destroy? do
    it "allows MAAP managers to destroy seats" do
      expect(subject).to permit(pundit_user_maap_manager, seat)
    end

    it "denies active employees from destroying seats" do
      expect(subject).not_to permit(pundit_user_active_employee, seat)
    end

    it "denies external users from destroying seats" do
      expect(subject).not_to permit(pundit_user_external_user, seat)
    end
  end

  permissions :reconcile? do
    it "allows MAAP managers to reconcile seats" do
      expect(subject).to permit(pundit_user_maap_manager, seat)
    end

    it "denies active employees from reconciling seats" do
      expect(subject).not_to permit(pundit_user_active_employee, seat)
    end

    it "denies external users from reconciling seats" do
      expect(subject).not_to permit(pundit_user_external_user, seat)
    end
  end

  describe "policy scope" do
    let!(:draft_seat) { create(:seat, :draft, title: title, seat_needed_by: Date.current + 1.month) }
    let!(:open_seat) { create(:seat, :open, title: title, seat_needed_by: Date.current + 2.months) }
    let!(:filled_seat) { create(:seat, :filled, title: title, seat_needed_by: Date.current + 3.months) }
    let!(:archived_seat) { create(:seat, :archived, title: title, seat_needed_by: Date.current + 4.months) }

    context "for MAAP managers" do
      let(:scope) { Pundit.policy_scope(pundit_user_maap_manager, Seat.for_organization(organization)) }

      it "shows all seats in the organization" do
        expect(scope).to include(draft_seat, open_seat, filled_seat, archived_seat)
      end
    end

    context "for active employees" do
      let(:scope) { Pundit.policy_scope(pundit_user_active_employee, Seat.for_organization(organization)) }

      it "shows only open and filled seats in the organization" do
        expect(scope).to include(open_seat, filled_seat)
        expect(scope).not_to include(draft_seat, archived_seat)
      end
    end

    context "for external users" do
      let(:scope) { Pundit.policy_scope(pundit_user_external_user, Seat.for_organization(organization)) }

      it "shows no seats" do
        expect(scope).to be_empty
      end
    end
  end

  describe "consistency with policy(organization).manage_maap?" do
    it "create? returns same result as policy(organization).manage_maap? when org matches" do
      seat_policy = SeatPolicy.new(pundit_user_maap_manager, Seat.new)
      org_policy = OrganizationPolicy.new(pundit_user_maap_manager, organization)
      
      # Both should check viewing_teammate.can_manage_maap? when org matches
      expect(seat_policy.create?).to eq(org_policy.manage_maap?)
      expect(seat_policy.create?).to be true
    end

    it "create? returns false when viewing_teammate cannot manage MAAP" do
      seat_policy = SeatPolicy.new(pundit_user_active_employee, Seat.new)
      expect(seat_policy.create?).to be false
    end
  end
end
