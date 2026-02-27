# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHelper, type: :helper do
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
