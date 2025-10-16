require 'rails_helper'

RSpec.describe AssignmentCheckInForm, type: :form do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:assignment_tenure) do
    create(:assignment_tenure,
           teammate: teammate,
           assignment: assignment,
           anticipated_energy_percentage: 80,
           started_at: 1.month.ago)
  end
  let(:check_in) { create(:assignment_check_in, teammate: teammate, assignment: assignment) }
  let(:form) { AssignmentCheckInForm.new(check_in) }

  before do
    assignment_tenure
    form.current_person = person
    form.view_mode = :manager
  end

  describe 'validations' do
    it 'validates assignment_id presence' do
      form.assignment_id = nil
      expect(form).not_to be_valid
      expect(form.errors[:assignment_id]).to include("can't be blank")
    end

    it 'validates status inclusion' do
      form.status = 'invalid_status'
      expect(form).not_to be_valid
      expect(form.errors[:status]).to include('is not included in the list')
    end

    it 'validates employee_rating inclusion' do
      form.employee_rating = 'invalid_rating'
      expect(form).not_to be_valid
      expect(form.errors[:employee_rating]).to include('is not included in the list')
    end

    it 'validates manager_rating inclusion' do
      form.manager_rating = 'invalid_rating'
      expect(form).not_to be_valid
      expect(form.errors[:manager_rating]).to include('is not included in the list')
    end

    it 'validates actual_energy_percentage range' do
      form.actual_energy_percentage = 150
      expect(form).not_to be_valid
      expect(form.errors[:actual_energy_percentage]).to include('must be in 0..100')
    end

    it 'validates employee_personal_alignment inclusion' do
      form.employee_personal_alignment = 'invalid_alignment'
      expect(form).not_to be_valid
      expect(form.errors[:employee_personal_alignment]).to include('is not included in the list')
    end
  end

  describe 'save behavior' do
    before do
      form.assignment_id = assignment.id
    end

    context 'when status is complete' do
      it 'completes manager side when view_mode is manager' do
        form.view_mode = :manager
        form.manager_rating = 'meeting'
        form.status = 'complete'

        expect(form).to be_valid
        expect(form.save).to be true
        expect(check_in.reload.manager_completed?).to be true
        expect(check_in.manager_completed_by).to eq(person)
      end

      it 'completes employee side when view_mode is employee' do
        form.view_mode = :employee
        form.employee_rating = 'exceeding'
        form.status = 'complete'

        expect(form).to be_valid
        expect(form.save).to be true
        expect(check_in.reload.employee_completed?).to be true
      end
    end

    context 'when status is draft' do
      it 'uncompletes manager side when view_mode is manager' do
        check_in.update!(manager_completed_at: Time.current, manager_completed_by: person)
        form.view_mode = :manager
        form.status = 'draft'

        expect(form).to be_valid
        expect(form.save).to be true
        expect(check_in.reload.manager_completed?).to be false
      end

      it 'uncompletes employee side when view_mode is employee' do
        check_in.update!(employee_completed_at: Time.current)
        form.view_mode = :employee
        form.status = 'draft'

        expect(form).to be_valid
        expect(form.save).to be true
        expect(check_in.reload.employee_completed?).to be false
      end
    end

    context 'when status is blank' do
      it 'does not change completion status' do
        form.manager_rating = 'meeting'
        form.status = nil

        expect(form).to be_valid
        expect(form.save).to be true
        expect(check_in.reload.manager_completed?).to be false
      end
    end
  end

  describe 'form properties' do
    it 'has all required properties' do
      expect(form).to respond_to(:employee_rating)
      expect(form).to respond_to(:manager_rating)
      expect(form).to respond_to(:employee_private_notes)
      expect(form).to respond_to(:manager_private_notes)
      expect(form).to respond_to(:actual_energy_percentage)
      expect(form).to respond_to(:employee_personal_alignment)
      expect(form).to respond_to(:status)
      expect(form).to respond_to(:assignment_id)
    end

    it 'sets current_person and view_mode' do
      expect(form.current_person).to eq(person)
      expect(form.view_mode).to eq(:manager)
    end
  end
end
