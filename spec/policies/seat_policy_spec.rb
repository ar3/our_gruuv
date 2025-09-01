require 'rails_helper'

RSpec.describe SeatPolicy, type: :policy do
  subject { described_class }

  let(:organization) { create(:organization, :company) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:seat) { create(:seat, position_type: position_type) }
  
  let(:maap_manager) { create(:person) }
  let(:active_employee) { create(:person) }
  let(:external_user) { create(:person) }

  before do
    # Set up permissions
    allow(maap_manager).to receive(:can_manage_maap?).with(organization).and_return(true)
    allow(maap_manager).to receive(:active_employment_tenure_in?).with(organization).and_return(false)
    
    allow(active_employee).to receive(:can_manage_maap?).with(organization).and_return(false)
    allow(active_employee).to receive(:active_employment_tenure_in?).with(organization).and_return(true)
    
    allow(external_user).to receive(:can_manage_maap?).with(organization).and_return(false)
    allow(external_user).to receive(:active_employment_tenure_in?).with(organization).and_return(false)
  end

  permissions :index? do
    it "allows active employees to view seats" do
      # Mock scope context to pass organization
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).to permit(active_employee, Seat)
    end

    it "allows MAAP managers to view seats" do
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).to permit(maap_manager, Seat)
    end

    it "denies external users" do
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).not_to permit(external_user, Seat)
    end
  end

  permissions :show? do
    it "allows active employees to view seats" do
      expect(subject).to permit(active_employee, seat)
    end

    it "allows MAAP managers to view seats" do
      expect(subject).to permit(maap_manager, seat)
    end

    it "denies external users" do
      expect(subject).not_to permit(external_user, seat)
    end
  end

  permissions :create? do
    it "allows MAAP managers to create seats" do
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).to permit(maap_manager, Seat)
    end

    it "denies active employees from creating seats" do
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).not_to permit(active_employee, Seat)
    end

    it "denies external users from creating seats" do
      allow(Seat).to receive(:context).and_return({ organization: organization })
      expect(subject).not_to permit(external_user, Seat)
    end
  end

  permissions :update? do
    it "allows MAAP managers to update seats" do
      expect(subject).to permit(maap_manager, seat)
    end

    it "denies active employees from updating seats" do
      expect(subject).not_to permit(active_employee, seat)
    end

    it "denies external users from updating seats" do
      expect(subject).not_to permit(external_user, seat)
    end
  end

  permissions :destroy? do
    it "allows MAAP managers to destroy seats" do
      expect(subject).to permit(maap_manager, seat)
    end

    it "denies active employees from destroying seats" do
      expect(subject).not_to permit(active_employee, seat)
    end

    it "denies external users from destroying seats" do
      expect(subject).not_to permit(external_user, seat)
    end
  end

  permissions :reconcile? do
    it "allows MAAP managers to reconcile seats" do
      expect(subject).to permit(maap_manager, seat)
    end

    it "denies active employees from reconciling seats" do
      expect(subject).not_to permit(active_employee, seat)
    end

    it "denies external users from reconciling seats" do
      expect(subject).not_to permit(external_user, seat)
    end
  end

  describe "policy scope" do
    let!(:draft_seat) { create(:seat, :draft, position_type: position_type, seat_needed_by: Date.current + 1.month) }
    let!(:open_seat) { create(:seat, :open, position_type: position_type, seat_needed_by: Date.current + 2.months) }
    let!(:filled_seat) { create(:seat, :filled, position_type: position_type, seat_needed_by: Date.current + 3.months) }
    let!(:archived_seat) { create(:seat, :archived, position_type: position_type, seat_needed_by: Date.current + 4.months) }

    context "for MAAP managers" do
      let(:scope) { Pundit.policy_scope(maap_manager, Seat) }

      it "shows all seats in the organization" do
        # Mock the scope context to pass organization
        allow(Seat).to receive(:context).and_return({ organization: organization })
        expect(scope).to include(draft_seat, open_seat, filled_seat, archived_seat)
      end
    end

    context "for active employees" do
      let(:scope) { Pundit.policy_scope(active_employee, Seat) }

      it "shows only open and filled seats in the organization" do
        # Mock the scope context to pass organization
        allow(Seat).to receive(:context).and_return({ organization: organization })
        expect(scope).to include(open_seat, filled_seat)
        expect(scope).not_to include(draft_seat, archived_seat)
      end
    end

    context "for external users" do
      let(:scope) { Pundit.policy_scope(external_user, Seat) }

      it "shows no seats" do
        # Mock the scope context to pass organization
        allow(Seat).to receive(:context).and_return({ organization: organization })
        expect(scope).to be_empty
      end
    end
  end
end
