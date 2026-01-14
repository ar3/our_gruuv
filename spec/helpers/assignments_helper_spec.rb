require 'rails_helper'

RSpec.describe AssignmentsHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:consumer_assignment1) { create(:assignment, company: organization, title: 'Consumer Assignment 1') }
  let(:consumer_assignment2) { create(:assignment, company: organization, title: 'Consumer Assignment 2') }

  describe '#assignment_outcome_consumer_assignment_label' do
    context 'when filter is active_consumer' do
      context 'when there are consumer assignments' do
        before do
          create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer_assignment1)
          create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer_assignment2)
        end

        it 'returns sentence with list of consumer assignments' do
          result = helper.assignment_outcome_consumer_assignment_label('active_consumer', assignment)
          expect(result).to include('Teammates who ARE taking on:')
          expect(result).to include('Consumer Assignment 1')
          expect(result).to include('Consumer Assignment 2')
        end
      end

      context 'when there are no consumer assignments' do
        it 'returns sentence with placeholder text' do
          result = helper.assignment_outcome_consumer_assignment_label('active_consumer', assignment)
          expect(result).to eq('Teammates who ARE taking on: associated assignment that can be defined')
        end
      end
    end

    context 'when filter is not_consumer' do
      context 'when there are consumer assignments' do
        before do
          create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer_assignment1)
          create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: consumer_assignment2)
        end

        it 'returns sentence with list of consumer assignments' do
          result = helper.assignment_outcome_consumer_assignment_label('not_consumer', assignment)
          expect(result).to include('Teammates who ARE NOT taking on:')
          expect(result).to include('Consumer Assignment 1')
          expect(result).to include('Consumer Assignment 2')
        end
      end

      context 'when there are no consumer assignments' do
        it 'returns sentence with placeholder text' do
          result = helper.assignment_outcome_consumer_assignment_label('not_consumer', assignment)
          expect(result).to eq('Teammates who ARE NOT taking on: associated assignment that can be defined')
        end
      end
    end

    context 'when filter is nil' do
      it 'returns nil' do
        result = helper.assignment_outcome_consumer_assignment_label(nil, assignment)
        expect(result).to be_nil
      end
    end

    context 'when filter is empty string' do
      it 'returns nil' do
        result = helper.assignment_outcome_consumer_assignment_label('', assignment)
        expect(result).to be_nil
      end
    end
  end
end
