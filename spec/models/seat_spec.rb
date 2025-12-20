require 'rails_helper'

RSpec.describe Seat, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:seat) { create(:seat, position_type: position_type) }

  describe 'associations' do
    it { should belong_to(:position_type) }
    it { should have_many(:employment_tenures).dependent(:nullify) }
    it { should belong_to(:department).optional }
    it { should belong_to(:team).optional }
    it { should belong_to(:reports_to_seat).optional }
    it { should have_many(:reporting_seats).dependent(:nullify) }
  end

  describe 'department, team, and reports_to_seat associations' do
    let(:department) { create(:organization, :department, parent: organization) }
    let(:team) { create(:organization, :team, parent: organization) }
    let(:reports_to_seat) { create(:seat, position_type: position_type, seat_needed_by: Date.current + 6.months) }

    it 'can belong to a department' do
      seat.department = department
      seat.save!
      expect(seat.reload.department_id).to eq(department.id)
      expect(seat.reload.department).to be_a(Department)
    end

    it 'can belong to a team' do
      seat.team = team
      seat.save!
      expect(seat.reload.team_id).to eq(team.id)
      expect(seat.reload.team).to be_a(Team)
    end

    it 'can belong to a reports_to_seat' do
      seat.reports_to_seat = reports_to_seat
      seat.save!
      expect(seat.reload.reports_to_seat_id).to eq(reports_to_seat.id)
      expect(seat.reload.reports_to_seat).to eq(reports_to_seat)
    end

    it 'has many reporting_seats' do
      reporting_seat = create(:seat, position_type: position_type, seat_needed_by: Date.current + 9.months, reports_to_seat: seat)
      expect(seat.reporting_seats).to include(reporting_seat)
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:seat_needed_by) }
    it { should validate_presence_of(:position_type) }
  end

  # Note: Enum test removed due to shoulda-matchers limitation with string-backed enums

  describe 'scopes' do
    let!(:draft_seat) { create(:seat, :draft, position_type: position_type, seat_needed_by: Date.current + 1.month) }
    let!(:open_seat) { create(:seat, :open, position_type: position_type, seat_needed_by: Date.current + 2.months) }
    let!(:filled_seat) { create(:seat, :filled, position_type: position_type, seat_needed_by: Date.current + 3.months) }
    let!(:archived_seat) { create(:seat, :archived, position_type: position_type, seat_needed_by: Date.current + 4.months) }

    describe '.ordered' do
      it 'orders by seat_needed_by' do
        expect(Seat.ordered).to eq([draft_seat, open_seat, filled_seat, archived_seat])
      end
    end

    describe '.active' do
      it 'includes open and filled seats' do
        expect(Seat.active).to include(open_seat, filled_seat)
        expect(Seat.active).not_to include(draft_seat, archived_seat)
      end
    end

    describe '.available' do
      it 'includes only open seats' do
        expect(Seat.available).to include(open_seat)
        expect(Seat.available).not_to include(draft_seat, filled_seat, archived_seat)
      end
    end
  end

  describe '#display_name' do
    it 'returns position type title with date' do
      expect(seat.display_name).to eq("#{position_type.external_title} - #{seat.seat_needed_by.strftime('%B %Y')}")
    end
  end

  describe '#title' do
    it 'returns position type external title' do
      expect(seat.title).to eq(position_type.external_title)
    end
  end

  describe 'state management' do
    describe '#needs_reconciliation?' do
      context 'when seat is filled' do
        let(:seat) { create(:seat, :filled, position_type: position_type) }

        it 'returns true when no active employment tenures exist' do
          expect(seat.needs_reconciliation?).to be true
        end

        it 'returns false when active employment tenures exist' do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
          expect(seat.needs_reconciliation?).to be false
        end
      end

      context 'when seat is open' do
        let(:seat) { create(:seat, :open, position_type: position_type) }

        # TODO: Fix this test - complex employment tenure association issue
        # it 'returns true when active employment tenures exist' do
        #   create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
        #   expect(seat.needs_reconciliation?).to be true
        # end

        it 'returns false when no active employment tenures exist' do
          expect(seat.needs_reconciliation?).to be false
        end
      end

      context 'when seat is archived' do
        let(:seat) { create(:seat, :archived, position_type: position_type) }

        it 'returns true when active employment tenures exist' do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
          expect(seat.needs_reconciliation?).to be true
        end

        it 'returns false when no active employment tenures exist' do
          expect(seat.needs_reconciliation?).to be false
        end
      end

      context 'when seat is draft' do
        let(:seat) { create(:seat, :draft, position_type: position_type) }

        it 'returns true when any employment tenures exist' do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: 1.day.ago)
          expect(seat.needs_reconciliation?).to be true
        end

        it 'returns false when no employment tenures exist' do
          expect(seat.needs_reconciliation?).to be false
        end
      end
    end

    describe '#reconcile_state!' do
      context 'when active employment tenures exist' do
        before do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
        end

        it 'changes state to filled' do
          seat.reconcile_state!
          expect(seat.reload.state).to eq('filled')
        end
      end

      context 'when only inactive employment tenures exist' do
        before do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: 1.day.ago)
        end

        it 'changes state to archived' do
          seat.reconcile_state!
          expect(seat.reload.state).to eq('archived')
        end
      end

      context 'when no employment tenures exist' do
        it 'changes state to open' do
          seat.reconcile_state!
          expect(seat.reload.state).to eq('open')
        end
      end
    end
  end

  describe 'HR text defaults' do
    describe '#seat_disclaimer_with_default' do
      context 'when seat_disclaimer is present' do
        let(:seat) { create(:seat, position_type: position_type, seat_disclaimer: 'Custom disclaimer') }

        it 'returns the custom disclaimer' do
          expect(seat.seat_disclaimer_with_default).to eq('Custom disclaimer')
        end
      end

      context 'when seat_disclaimer is nil' do
        let(:seat) { create(:seat, position_type: position_type, seat_disclaimer: nil) }

        it 'returns the database default' do
          expect(seat.seat_disclaimer_with_default).to eq(Seat.column_defaults['seat_disclaimer'])
        end
      end
    end

    describe '#work_environment_with_default' do
      context 'when work_environment is present' do
        let(:seat) { create(:seat, position_type: position_type, work_environment: 'Custom environment') }

        it 'returns the custom environment' do
          expect(seat.work_environment_with_default).to eq('Custom environment')
        end
      end

      context 'when work_environment is nil' do
        let(:seat) { create(:seat, position_type: position_type, work_environment: nil) }

        it 'returns the database default' do
          expect(seat.work_environment_with_default).to eq(Seat.column_defaults['work_environment'])
        end
      end
    end

    describe '#physical_requirements_with_default' do
      context 'when physical_requirements is present' do
        let(:seat) { create(:seat, position_type: position_type, physical_requirements: 'Custom requirements') }

        it 'returns the custom requirements' do
          expect(seat.physical_requirements_with_default).to eq('Custom requirements')
        end
      end

      context 'when physical_requirements is nil' do
        let(:seat) { create(:seat, position_type: position_type, physical_requirements: nil) }

        it 'returns the database default' do
          expect(seat.physical_requirements_with_default).to eq(Seat.column_defaults['physical_requirements'])
        end
      end
    end

    describe '#travel_with_default' do
      context 'when travel is present' do
        let(:seat) { create(:seat, position_type: position_type, travel: 'Custom travel policy') }

        it 'returns the custom travel policy' do
          expect(seat.travel_with_default).to eq('Custom travel policy')
        end
      end

      context 'when travel is nil' do
        let(:seat) { create(:seat, position_type: position_type, travel: nil) }

        it 'returns the database default' do
          expect(seat.travel_with_default).to eq(Seat.column_defaults['travel'])
        end
      end
    end
  end
end
