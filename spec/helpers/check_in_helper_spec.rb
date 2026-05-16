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

    it 'returns bg-success when within crystal clear days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 30.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-success')
    end

    it 'returns bg-info text-dark when between crystal clear and clear windows' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 45.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-info text-dark')
    end

    it 'returns bg-warning text-dark when between clear and blurred windows' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 75.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-warning text-dark')
    end

    it 'returns bg-danger when more than 90 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 100.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-danger')
    end

    it 'returns bg-success at 30 days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 30.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-success')
    end

    it 'returns bg-info at 46 days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 46.days.ago)
      expect(helper.last_finalized_pill_class(check_in)).to eq('bg-info text-dark')
    end

    it 'returns bg-warning at 61 days' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 61.days.ago)
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

    it 'returns true when last finalized within crystal clear window' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 30.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(true)
    end

    it 'returns false when last finalized in clear window' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 46.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(false)
    end

    it 'returns false when last finalized more than 90 days ago' do
      check_in = instance_double('PositionCheckIn', official_check_in_completed_at: 100.days.ago)
      expect(helper.last_finalized_recent?(check_in)).to eq(false)
    end
  end

  describe '#complete_picture_next_check_in_word' do
    it 'returns "now" when anchor time is blank' do
      expect(helper.complete_picture_next_check_in_word(nil)).to eq('now')
    end

    it 'returns "now" when the clear-window deadline is in the past (warning band)' do
      anchor = 80.days.ago
      expect(helper.complete_picture_next_check_in_word(anchor)).to eq('now')
    end

    it 'returns a future distance when within crystal clear band' do
      anchor = 5.days.ago
      word = helper.complete_picture_next_check_in_word(anchor)
      expect(word).not_to eq('now')
      expect(word).to be_a(String)
      expect(word.length).to be_positive
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

  describe '#single_item_check_in_counterparty_ready_review_clause' do
    let(:organization) { create(:organization) }
    let(:employee_person) { create(:person, first_name: 'Jamie', last_name: 'Emp') }
    let(:manager_person) { create(:person, first_name: 'Morgan', last_name: 'Mgr') }
    let(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
    let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }

    before do
      allow(employee_teammate).to receive(:current_manager).and_return(manager_person)
    end

    it 'returns empty string when check_in is nil' do
      expect(helper.single_item_check_in_counterparty_ready_review_clause(nil, employee_teammate, employee_person)).to eq('')
    end

    it 'when viewing as employee and manager has not completed, names manager' do
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        manager_completed_at: nil)
      expect(helper.single_item_check_in_counterparty_ready_review_clause(check_in, employee_teammate, employee_person))
        .to eq("#{manager_person.casual_name} has not completed their check-in yet.")
    end

    it 'when viewing as employee and manager completed, includes time ago' do
      completed = 2.days.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        manager_completed_at: completed,
        manager_completed_by_teammate: manager_teammate,
        manager_rating: 'meeting',
        manager_private_notes: 'ok')
      allow(helper).to receive(:time_ago_in_words).with(completed).and_return('2 days')
      expect(helper.single_item_check_in_counterparty_ready_review_clause(check_in, employee_teammate, employee_person))
        .to eq("#{manager_person.casual_name} has reflected on this and marked their check-in ready for review 2 days ago.")
    end

    it 'when viewing as manager and employee has not completed, names employee' do
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: nil)
      expect(helper.single_item_check_in_counterparty_ready_review_clause(check_in, employee_teammate, manager_person))
        .to eq("#{employee_person.casual_name} has not completed their check-in yet.")
    end

    it 'when viewing as manager and employee completed, includes time ago' do
      completed = 5.hours.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: completed,
        employee_rating: 'meeting',
        employee_private_notes: 'notes')
      allow(helper).to receive(:time_ago_in_words).with(completed).and_return('about 5 hours')
      expect(helper.single_item_check_in_counterparty_ready_review_clause(check_in, employee_teammate, manager_person))
        .to eq("#{employee_person.casual_name} has reflected on this and marked their check-in ready for review about 5 hours ago.")
    end
  end

  describe '#single_item_check_in_primary_caption' do
    let(:organization) { create(:organization) }
    let(:employee_person) { create(:person, first_name: 'Jamie', last_name: 'Emp') }
    let(:manager_person) { create(:person, first_name: 'Morgan', last_name: 'Mgr') }
    let(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }

    before do
      allow(employee_teammate).to receive(:current_manager).and_return(manager_person)
    end

    it 'when complete and other side incomplete, states they cannot see the response yet' do
      completed_at = 2.days.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: completed_at, manager_completed_at: nil)

      allow(helper).to receive(:time_ago_in_words).with(completed_at).and_return('2 days')

      expect(
        helper.single_item_check_in_primary_caption(
          is_complete: true,
          counterparty_name: manager_person.casual_name,
          completed_at: completed_at,
          check_in: check_in,
          teammate: employee_teammate,
          current_person: employee_person
        )
      ).to eq(
        "You completed your individual check-in 2 days ago. #{manager_person.casual_name} has not completed their side of the check-in and therefore cannot see your response yet."
      )
    end

    it 'when complete and both sides complete, states visible-since based on earlier completion and links review together to finalization' do
      your_completed_at = 1.day.ago
      manager_completed_at = 3.days.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: your_completed_at, manager_completed_at: manager_completed_at)

      allow(helper).to receive(:time_ago_in_words).with(your_completed_at).and_return('1 day')
      allow(helper).to receive(:time_ago_in_words).with(manager_completed_at).and_return('3 days')

      finalization_path = helper.organization_company_teammate_finalization_path(organization, employee_teammate)
      result = helper.single_item_check_in_primary_caption(
        is_complete: true,
        counterparty_name: manager_person.casual_name,
        completed_at: your_completed_at,
        check_in: check_in,
        teammate: employee_teammate,
        current_person: employee_person,
        organization: organization
      )

      expect(result).to be_html_safe
      expect(result).to include(finalization_path)
      expect(result).to include('>review together</a>')
      expect(result).to include('You completed your individual check-in 1 day ago.')
      expect(result).to include('and you are ready to have your ')
    end

    it 'when complete and both sides complete as manager, links review together to the employee teammate finalization page' do
      your_completed_at = 1.day.ago
      manager_completed_at = 3.days.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: your_completed_at, manager_completed_at: manager_completed_at)

      allow(helper).to receive(:time_ago_in_words).with(your_completed_at).and_return('1 day')
      allow(helper).to receive(:time_ago_in_words).with(manager_completed_at).and_return('3 days')

      finalization_path = helper.organization_company_teammate_finalization_path(organization, employee_teammate)
      result = helper.single_item_check_in_primary_caption(
        is_complete: true,
        counterparty_name: employee_person.casual_name,
        completed_at: manager_completed_at,
        check_in: check_in,
        teammate: employee_teammate,
        current_person: manager_person,
        organization: organization
      )

      expect(result).to be_html_safe
      expect(result).to include(finalization_path)
      expect(result).to include('>review together</a>')
      expect(result).to include('You completed your individual check-in 3 days ago.')
      expect(result).to include("#{employee_person.casual_name} completed their individual check-in 1 day ago")
    end

    it 'when draft and other side incomplete, says they will not see response immediately' do
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: nil)

      expect(
        helper.single_item_check_in_primary_caption(
          is_complete: false,
          counterparty_name: manager_person.casual_name,
          completed_at: nil,
          check_in: check_in,
          teammate: employee_teammate,
          current_person: employee_person
        )
      ).to eq(
        "#{manager_person.casual_name} has not completed their individual check-in on this yet, and will not see your response immediately... they will only after they complete their side first."
      )
    end

    it 'when draft and other side complete, says both responses become visible on click' do
      manager_completed_at = 3.days.ago
      check_in = build(:aspiration_check_in, teammate: employee_teammate, aspiration: aspiration,
        employee_completed_at: nil, manager_completed_at: manager_completed_at)

      expect(
        helper.single_item_check_in_primary_caption(
          is_complete: false,
          counterparty_name: manager_person.casual_name,
          completed_at: nil,
          check_in: check_in,
          teammate: employee_teammate,
          current_person: employee_person
        )
      ).to eq(
        "#{manager_person.casual_name} has completed their individual check-in and you will be able to see their response and they will be able to see your response when you click this button."
      )
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

  describe '#review_most_recent_joint_review_button_label' do
    let(:organization) { create(:organization) }
    let(:employee_person) { create(:person, first_name: 'Alex', last_name: 'Emp') }
    let(:teammate) { create(:company_teammate, person: employee_person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization, title: 'Q4 Rollout') }
    let(:aspiration) { create(:aspiration, company: organization, name: 'Integrity') }
    let(:employment_tenure) { create(:employment_tenure, company_teammate: teammate, company: organization) }

    it 'returns empty string when check_in is nil' do
      expect(helper.review_most_recent_joint_review_button_label(nil, 'Al', 'Bo')).to eq('')
    end

    it 'includes aspiration name for AspirationCheckIn' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration)
      expect(helper.review_most_recent_joint_review_button_label(check_in, 'Alex', 'Mo')).to eq(
        'Time for Alex and Mo to review Integrity together!'
      )
    end

    it 'includes assignment title for AssignmentCheckIn' do
      check_in = build(:assignment_check_in, teammate: teammate, assignment: assignment)
      expect(helper.review_most_recent_joint_review_button_label(check_in, 'Alex', 'Mo')).to eq(
        'Time for Alex and Mo to review Q4 Rollout together!'
      )
    end

    it 'includes position display name for PositionCheckIn' do
      check_in = build(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
      expected_object = employment_tenure.position.display_name
      expect(helper.review_most_recent_joint_review_button_label(check_in, 'Alex', 'Mo')).to eq(
        "Time for Alex and Mo to review #{expected_object} together!"
      )
    end
  end

  describe '#check_ins_awaiting_input_group_header' do
    let(:organization) { create(:organization) }
    let(:employee_person) { create(:person, preferred_name: 'Alex') }
    let(:manager_person) { create(:person, preferred_name: 'Mo') }
    let(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
    let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization, title: 'Ship Feature') }

    it 'uses manager-focused copy when the viewer is the employee' do
      check_in = create(:assignment_check_in,
                        teammate: employee_teammate,
                        assignment: assignment,
                        manager_completed_at: Time.current,
                        manager_completed_by_teammate: manager_teammate,
                        employee_completed_at: nil)

      expect(helper.check_ins_awaiting_input_group_header([check_in], employee_teammate, employee_teammate))
        .to eq('Your manager has completed their side of your 1 check-in')
    end

    it 'uses employee-focused copy when the viewer is the manager' do
      check_in = create(:assignment_check_in,
                        teammate: employee_teammate,
                        assignment: assignment,
                        employee_completed_at: Time.current,
                        manager_completed_at: nil)

      expect(helper.check_ins_awaiting_input_group_header([check_in], employee_teammate, manager_teammate))
        .to eq('Alex has completed their side of 1 check-in and is awaiting you to complete your side')
    end

    it 'pluralizes manager label and awaiting verb for multiple check-ins' do
      second_assignment = create(:assignment, company: organization, title: 'Other Work')
      check_ins = [
        create(:assignment_check_in,
               teammate: employee_teammate,
               assignment: assignment,
               employee_completed_at: Time.current,
               manager_completed_at: nil),
        create(:assignment_check_in,
               teammate: employee_teammate,
               assignment: second_assignment,
               employee_completed_at: Time.current,
               manager_completed_at: nil)
      ]

      expect(helper.check_ins_awaiting_input_group_header(check_ins, employee_teammate, manager_teammate))
        .to eq('Alex has completed their side of 2 check-ins and are awaiting you to complete your side')
    end
  end

  describe '#check_ins_awaiting_input_detail_line' do
    let(:organization) { create(:organization) }
    let(:employee_person) { create(:person, preferred_name: 'Alex') }
    let(:manager_person) { create(:person, preferred_name: 'Mo') }
    let(:employee_teammate) { create(:company_teammate, person: employee_person, organization: organization) }
    let(:manager_teammate) { create(:company_teammate, person: manager_person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization, title: 'Ship Feature') }

    it 'describes the completer, object, and date range with bold emphasis' do
      started_on = Date.new(2026, 1, 1)
      completed_at = Time.zone.local(2026, 2, 15, 12, 0, 0)
      check_in = create(:assignment_check_in,
                        teammate: employee_teammate,
                        assignment: assignment,
                        check_in_started_on: started_on,
                        employee_completed_at: completed_at,
                        manager_completed_at: nil)

      html = helper.check_ins_awaiting_input_detail_line(check_in)

      expect(html).to include('Alex completed a check-in about the Assignment,')
      expect(html).to include('<strong>Ship Feature</strong>')
      expect(html).to include('<strong>Feb 15, 2026</strong>')
      expect(html).to include('their take on Alex and')
      expect(html).to include('<strong>Jan 01, 2026</strong>')
    end
  end

  describe '#get_shit_done_check_in_review_path' do
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:assignment) { create(:assignment, company: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }
    let(:employment_tenure) { create(:employment_tenure, company_teammate: teammate, company: organization) }

    it 'returns the 1-by-1 assignment check-in path for AssignmentCheckIn' do
      check_in = build(:assignment_check_in, teammate: teammate, assignment: assignment)
      expected = helper.organization_teammate_assignment_path(organization, teammate, assignment)
      expect(helper.get_shit_done_check_in_review_path(organization, check_in)).to eq(expected)
    end

    it 'returns the 1-by-1 aspiration check-in path for AspirationCheckIn' do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration)
      expected = helper.organization_teammate_aspiration_path(organization, teammate, aspiration)
      expect(helper.get_shit_done_check_in_review_path(organization, check_in)).to eq(expected)
    end

    it 'returns the position check-in path for PositionCheckIn' do
      check_in = build(:position_check_in, teammate: teammate, employment_tenure: employment_tenure)
      expected = helper.position_check_in_organization_teammate_path(organization, teammate)
      expect(helper.get_shit_done_check_in_review_path(organization, check_in)).to eq(expected)
    end
  end

  describe "#single_item_check_in_mandatory_delete_blocked?" do
    let(:organization) { create(:organization) }
    let(:teammate) { create(:company_teammate, organization: organization) }
    let(:assignment) { create(:assignment, company: organization) }
    let(:aspiration) { create(:aspiration, company: organization) }
    let(:dept_aspiration) { create(:aspiration, :with_department, company: organization) }

    it "is true for company-level aspiration check-in" do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: aspiration)
      expect(helper.single_item_check_in_mandatory_delete_blocked?(check_in, teammate, organization)).to eq(true)
    end

    it "is false for department aspiration check-in" do
      check_in = build(:aspiration_check_in, teammate: teammate, aspiration: dept_aspiration)
      expect(helper.single_item_check_in_mandatory_delete_blocked?(check_in, teammate, organization)).to eq(false)
    end

    it "is false for assignment check-in when not required on position" do
      check_in = build(:assignment_check_in, teammate: teammate, assignment: assignment)
      expect(helper.single_item_check_in_mandatory_delete_blocked?(check_in, teammate, organization)).to eq(false)
    end
  end
end
