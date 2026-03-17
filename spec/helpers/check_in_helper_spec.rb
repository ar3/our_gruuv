# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHelper, type: :helper do
  describe '#last_finalized_label' do
    it 'returns "Never Finalized" when latest_check_in is nil' do
      expect(helper.last_finalized_label(nil)).to eq('Never Finalized')
    end

    it 'returns "Last Finalized X ago" when latest_check_in is present' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 2.days.ago)
      allow(helper).to receive(:time_ago_in_words).and_return('2 days')
      expect(helper.last_finalized_label(check_in)).to eq('Last Finalized 2 days ago')
    end
  end

  describe '#last_finalized_pill_class' do
    it 'returns bg-secondary when latest_check_in is nil' do
      expect(helper.last_finalized_pill_class(nil)).to eq('bg-secondary')
    end

    it 'returns bg-success when 45 days ago or less' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 30.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-success')
    end

    it 'returns bg-warning text-dark when 46-90 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 75.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-warning text-dark')
    end

    it 'returns bg-danger when more than 90 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 100.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-danger')
    end

    it 'returns bg-success at 44 days (within 45-day window)' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 44.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-success')
    end

    it 'returns bg-warning at 46 days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 46.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-warning text-dark')
    end

    it 'returns bg-danger at 91 days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 91.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-danger')
    end
  end

  describe '#last_finalized_recent?' do
    it 'returns false when latest_check_in is nil' do
      expect(helper.last_finalized_recent?(nil)).to eq(false)
    end

    it 'returns true when last finalized 45 days ago or less' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 30.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(true)
    end

    it 'returns false when last finalized 46 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 46.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(false)
    end

    it 'returns false when last finalized more than 90 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 100.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(false)
    end
  end

  describe '#assignment_alignment_phrase_past' do
    it 'returns past-tense phrase for each alignment' do
      expect(helper.assignment_alignment_phrase_past('love')).to eq("they'd love to do it again")
      expect(helper.assignment_alignment_phrase_past('like')).to eq("they'd like to do it again")
      expect(helper.assignment_alignment_phrase_past('neutral')).to eq("they're indifferent about taking it on again")
      expect(helper.assignment_alignment_phrase_past('only_if_necessary')).to eq("they'd only take it on again if necessary")
      expect(helper.assignment_alignment_phrase_past('prefer_not')).to eq("they'd prefer not to take it on again")
    end

    it 'returns nil for blank alignment' do
      expect(helper.assignment_alignment_phrase_past(nil)).to be_nil
      expect(helper.assignment_alignment_phrase_past('')).to be_nil
    end
  end

  describe '#assignment_energy_alignment_sentence' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: 'Sam', last_name: 'Test') }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization, title: 'Project Alpha') }
    let(:check_in) do
      build(:assignment_check_in,
        teammate: teammate,
        assignment: assignment,
        actual_energy_percentage: 75,
        employee_personal_alignment: 'like'
      )
    end

    it 'returns sentence with bold casual name, assignment title, energy, and alignment' do
      sentence = helper.assignment_energy_alignment_sentence(check_in)
      expect(sentence).to be_html_safe
      expect(sentence).to include("<strong>#{person.casual_name}</strong>")
      expect(sentence).to include('<strong>Project Alpha</strong>')
      expect(sentence).to include('<strong>75</strong>%')
      # Apostrophe is HTML-escaped in output
      expect(sentence).to include('like to do it again')
      expect(sentence).to include('<strong>')
      expect(sentence).to include('they spent about <strong>75</strong>% of their energy on this assignment')
    end

    it 'returns empty string when check_in is nil' do
      expect(helper.assignment_energy_alignment_sentence(nil)).to eq('')
    end

    it 'returns empty string when both energy and alignment are blank' do
      check_in.actual_energy_percentage = nil
      check_in.employee_personal_alignment = nil
      expect(helper.assignment_energy_alignment_sentence(check_in)).to eq('')
    end

    it 'includes only energy part when alignment is blank' do
      check_in.employee_personal_alignment = nil
      sentence = helper.assignment_energy_alignment_sentence(check_in)
      expect(sentence).to include('they spent about <strong>75</strong>%')
      expect(sentence).not_to include(' and they ')
    end

    it 'includes only alignment part when energy is nil' do
      check_in.actual_energy_percentage = nil
      sentence = helper.assignment_energy_alignment_sentence(check_in)
      # Apostrophe is HTML-escaped in output
      expect(sentence).to include('like to do it again')
      expect(sentence).to include('<strong>')
      expect(sentence).not_to include('spent about')
    end
  end

  describe '#aspiration_check_in_status_label' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
    let(:manager_person) { create(:person, first_name: 'Bob', last_name: 'Manager') }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }

    context 'when check-in is officially completed' do
      let(:check_in) do
        build(:aspiration_check_in, :finalized, teammate: teammate, aspiration: aspiration, maap_snapshot: nil)
      end

      it 'returns "Acknowledged" when maap_snapshot is acknowledged' do
        snapshot = instance_double('MaapSnapshot', acknowledged?: true)
        allow(check_in).to receive(:maap_snapshot).and_return(snapshot)
        expect(helper.aspiration_check_in_status_label(check_in, 1.day.ago, teammate)).to eq('Acknowledged')
      end

      it 'returns "Waiting to be acknowledged" when maap_snapshot is not acknowledged' do
        snapshot = instance_double('MaapSnapshot', acknowledged?: false)
        allow(check_in).to receive(:maap_snapshot).and_return(snapshot)
        expect(helper.aspiration_check_in_status_label(check_in, 1.day.ago, teammate)).to eq('Waiting to be acknowledged')
      end
    end

    context 'when check-in is ready for finalization' do
      let(:check_in) do
        build(:aspiration_check_in, :ready_for_finalization, teammate: teammate, aspiration: aspiration)
      end

      it 'returns "Waiting to be reviewed"' do
        expect(helper.aspiration_check_in_status_label(check_in, 90.days.ago, teammate)).to eq('Waiting to be reviewed')
      end
    end

    context 'when check-in is open and last finalization was under 60 days ago' do
      let(:check_in) do
        build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
          employee_completed_at: nil, manager_completed_at: nil)
      end

      it 'returns "Nothing to do yet"' do
        expect(helper.aspiration_check_in_status_label(check_in, 30.days.ago, teammate)).to eq('Nothing to do yet')
      end
    end

    context 'when check-in is open and last finalization was over 60 days ago' do
      let(:check_in) do
        build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
          employee_completed_at: nil, manager_completed_at: nil)
      end

      it 'returns "Waiting for both" when neither side completed' do
        expect(helper.aspiration_check_in_status_label(check_in, 90.days.ago, teammate)).to eq('Waiting for both')
      end
    end
  end

  describe '#aspiration_check_in_waiting_for_name' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }

    it 'returns nil when both sides completed' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      expect(helper.aspiration_check_in_waiting_for_name(check_in, teammate)).to be_nil
    end

    it 'returns employee casual name when employee has not completed' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: 1.day.ago)
      expect(helper.aspiration_check_in_waiting_for_name(check_in, teammate)).to eq(person.casual_name)
    end

    it 'returns "Manager" when manager has not completed and no current_manager' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: 1.day.ago, manager_completed_at: nil)
      allow(teammate).to receive(:current_manager).and_return(nil)
      expect(helper.aspiration_check_in_waiting_for_name(check_in, teammate)).to eq('Manager')
    end
  end

  describe '#single_item_check_in_make_changes_needs_attention?' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: 'Jane', last_name: 'Doe') }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }

    it 'returns false when last finalized under 60 days ago (employee not completed)' do
      latest_finalized = instance_double('AspirationCheckIn', official_check_in_completed_at: 30.days.ago)
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: nil)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, :employee)).to eq(false)
    end

    it 'returns true when last finalized 60+ days ago and employee not completed' do
      latest_finalized = instance_double('AspirationCheckIn', official_check_in_completed_at: 70.days.ago)
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: nil)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, :employee)).to eq(true)
    end

    it 'returns false when last finalized 60+ days ago but employee completed' do
      latest_finalized = instance_double('AspirationCheckIn', official_check_in_completed_at: 70.days.ago)
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: 1.day.ago, manager_completed_at: nil)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, :employee)).to eq(false)
    end

    it 'returns true when never finalized and employee not completed' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: nil)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, nil, :employee)).to eq(true)
    end

    it 'returns true when last finalized 60+ days ago and manager not completed (manager role)' do
      latest_finalized = instance_double('AspirationCheckIn', official_check_in_completed_at: 70.days.ago)
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: 1.day.ago, manager_completed_at: nil)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, :manager)).to eq(true)
    end

    it 'returns false when last finalized 60+ days ago but manager completed (manager role)' do
      latest_finalized = instance_double('AspirationCheckIn', official_check_in_completed_at: 70.days.ago)
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration,
        employee_completed_at: 1.day.ago, manager_completed_at: 1.day.ago)
      expect(helper.single_item_check_in_make_changes_needs_attention?(check_in, latest_finalized, :manager)).to eq(false)
    end
  end
end
