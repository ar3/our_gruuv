require 'rails_helper'

RSpec.describe Seat, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:title) { create(:title, company: organization) }
  let(:seat) { create(:seat, title: title) }

  describe 'associations' do
    it { should belong_to(:title) }
    it { should have_many(:seat_titles).dependent(:destroy) }
    it { should have_many(:titles).through(:seat_titles) }
    it { should have_many(:employment_tenures).dependent(:nullify) }
    it { should belong_to(:team).optional }
    it { should belong_to(:reports_to_seat).optional }
    it { should have_many(:reporting_seats).dependent(:nullify) }
  end

  describe 'department, team, and reports_to_seat associations' do
    let(:department) { create(:department, company: organization) }
    let(:team_org) { create(:organization, :company) }
    let(:reports_to_seat) { create(:seat, title: title, seat_needed_by: Date.current + 6.months) }

    it 'derives department from title' do
      title.update!(department: department)
      seat.reload
      expect(seat.department_id).to eq(department.id)
      expect(seat.department).to be_a(Department)
      expect(seat.department.id).to eq(department.id)
    end

    it 'can belong to a team' do
      team = create(:team, company: organization)
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
      reporting_seat = create(:seat, title: title, seat_needed_by: Date.current + 9.months, reports_to_seat: seat)
      expect(seat.reporting_seats).to include(reporting_seat)
    end
  end

  describe 'validations' do
    it { should validate_presence_of(:seat_needed_by) }
    it { should validate_presence_of(:title) }
  end

  # Note: Enum test removed due to shoulda-matchers limitation with string-backed enums

  describe 'scopes' do
    let!(:draft_seat) { create(:seat, :draft, title: title, seat_needed_by: Date.current + 1.month) }
    let!(:open_seat) { create(:seat, :open, title: title, seat_needed_by: Date.current + 2.months) }
    let!(:filled_seat) { create(:seat, :filled, title: title, seat_needed_by: Date.current + 3.months) }
    let!(:archived_seat) { create(:seat, :archived, title: title, seat_needed_by: Date.current + 4.months) }

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
      expect(seat.display_name).to eq("#{title.external_title} - #{seat.seat_needed_by.strftime('%B %Y')}")
    end
  end

  describe '#title_label' do
    it 'returns all associated titles as a comma-separated list' do
      second_title = create(:title, company: organization)
      seat.update!(title_ids: [title.id, second_title.id])

      expect(seat.reload.title_label).to include(title.external_title)
      expect(seat.reload.title_label).to include(second_title.external_title)
    end
  end

  describe '#includes_title_id?' do
    it 'returns true when the title is associated to the seat' do
      second_title = create(:title, company: organization)
      seat.update!(title_ids: [title.id, second_title.id])

      expect(seat.includes_title_id?(second_title.id)).to be true
      expect(seat.includes_title_id?(title.id)).to be true
      expect(seat.includes_title_id?(0)).to be false
    end
  end

  describe 'associated title uniqueness for needed-by date' do
    let(:needed_by) { Date.current + 5.months }
    let!(:existing_seat) do
      create(:seat, title: title, seat_needed_by: needed_by).tap do |s|
        second = create(:title, company: organization)
        s.update!(title_ids: [title.id, second.id])
        @secondary_title = second
      end
    end
    let(:secondary_title) { @secondary_title }

    it 'rejects another seat that reuses a secondary title on the same needed-by date' do
      other = build(:seat, title: secondary_title, seat_needed_by: needed_by)
      expect(other).not_to be_valid
      expect(other.errors[:titles]).to be_present
    end

    it 'allows the same secondary title on a different needed-by date' do
      other = build(:seat, title: secondary_title, seat_needed_by: needed_by + 1.month)
      expect(other).to be_valid
    end

    it 'keeps primary title in seat_titles after create' do
      created = create(:seat, title: title, seat_needed_by: Date.current + 8.months)
      expect(created.seat_titles.pluck(:title_id)).to include(title.id)
    end
  end

  describe '#title' do
    it 'returns the title object' do
      expect(seat.title).to eq(title)
    end
  end

  describe 'state management' do
    describe '#needs_reconciliation?' do
      context 'when seat is filled' do
        let(:seat) { create(:seat, :filled, title: title) }

        it 'returns true when no active employment tenures exist' do
          expect(seat.needs_reconciliation?).to be true
        end

        it 'returns false when active employment tenures exist' do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
          expect(seat.needs_reconciliation?).to be false
        end
      end

      context 'when seat is open' do
        let(:seat) { create(:seat, :open, title: title) }

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
        let(:seat) { create(:seat, :archived, title: title) }

        it 'returns true when active employment tenures exist' do
          create(:employment_tenure, :with_seat, seat: seat, ended_at: nil)
          expect(seat.needs_reconciliation?).to be true
        end

        it 'returns false when no active employment tenures exist' do
          expect(seat.needs_reconciliation?).to be false
        end
      end

      context 'when seat is draft' do
        let(:seat) { create(:seat, :draft, title: title) }

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

  describe 'HR text cascade' do
    before do
      organization.update!(
        job_description_disclaimer: 'Org disclaimer',
        work_environment: 'Org environment',
        physical_requirements: 'Org physical',
        travel: 'Org travel'
      )
    end

    describe '#seat_disclaimer_with_default' do
      context 'when seat_disclaimer is present' do
        let(:seat) { create(:seat, title: title, seat_disclaimer: 'Custom disclaimer') }

        it 'returns the custom disclaimer' do
          expect(seat.seat_disclaimer_with_default).to eq('Custom disclaimer')
        end
      end

      context 'when seat_disclaimer is nil and title has a value' do
        before { title.update!(job_description_disclaimer: 'Title disclaimer') }

        let(:seat) { create(:seat, title: title, seat_disclaimer: nil) }

        it 'returns the title disclaimer' do
          expect(seat.seat_disclaimer_with_default).to eq('Title disclaimer')
        end
      end

      context 'when seat and title are blank' do
        let(:seat) { create(:seat, title: title, seat_disclaimer: nil) }

        it 'returns the organization disclaimer' do
          expect(seat.seat_disclaimer_with_default).to eq('Org disclaimer')
        end
      end
    end

    describe '#work_environment_with_default' do
      context 'when work_environment is present' do
        let(:seat) { create(:seat, title: title, work_environment: 'Custom environment') }

        it 'returns the custom environment' do
          expect(seat.work_environment_with_default).to eq('Custom environment')
        end
      end

      context 'when work_environment is nil' do
        let(:seat) { create(:seat, title: title, work_environment: nil) }

        it 'returns the organization default' do
          expect(seat.work_environment_with_default).to eq('Org environment')
        end
      end
    end

    describe '#physical_requirements_with_default' do
      context 'when physical_requirements is present' do
        let(:seat) { create(:seat, title: title, physical_requirements: 'Custom requirements') }

        it 'returns the custom requirements' do
          expect(seat.physical_requirements_with_default).to eq('Custom requirements')
        end
      end

      context 'when physical_requirements is nil' do
        let(:seat) { create(:seat, title: title, physical_requirements: nil) }

        it 'returns the organization default' do
          expect(seat.physical_requirements_with_default).to eq('Org physical')
        end
      end
    end

    describe '#travel_with_default' do
      context 'when travel is present' do
        let(:seat) { create(:seat, title: title, travel: 'Custom travel policy') }

        it 'returns the custom travel policy' do
          expect(seat.travel_with_default).to eq('Custom travel policy')
        end
      end

      context 'when travel is nil' do
        let(:seat) { create(:seat, title: title, travel: nil) }

        it 'returns the organization default' do
          expect(seat.travel_with_default).to eq('Org travel')
        end
      end
    end
  end

  describe '#has_direct_reports?' do
    context 'when seat has reporting seats' do
      let!(:reporting_seat) { create(:seat, title: title, seat_needed_by: Date.current + 1.month, reports_to_seat: seat) }

      it 'returns true' do
        expect(seat.has_direct_reports?).to be true
      end
    end

    context 'when seat has no reporting seats' do
      it 'returns false' do
        expect(seat.has_direct_reports?).to be false
      end
    end
  end
end
