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
end
