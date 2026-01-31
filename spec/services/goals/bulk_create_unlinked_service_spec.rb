# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Goals::BulkCreateUnlinkedService, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:owner_teammate) { teammate }
  let(:parsed_goals) do
    [
      { title: 'Goal 1', goal_type: 'quantitative_key_result', parent_index: nil },
      { title: 'Goal 2', goal_type: 'quantitative_key_result', parent_index: nil },
      { title: 'Goal 3', goal_type: 'quantitative_key_result', parent_index: nil }
    ]
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      service = described_class.new(
        organization, person, teammate, owner_teammate, parsed_goals
      )

      expect(service.organization).to eq(organization)
      expect(service.current_person).to eq(person)
      expect(service.current_teammate).to eq(teammate)
      expect(service.owner).to eq(owner_teammate)
      expect(service.parsed_goals).to eq(parsed_goals)
      expect(service.default_goal_type).to eq('quantitative_key_result')
      expect(service.privacy_level).to eq('only_creator_owner_and_managers')
    end

    it 'accepts custom default_goal_type and privacy_level' do
      service = described_class.new(
        organization, person, teammate, owner_teammate, parsed_goals,
        default_goal_type: 'stepping_stone_activity',
        privacy_level: 'everyone_in_company'
      )
      expect(service.default_goal_type).to eq('stepping_stone_activity')
      expect(service.privacy_level).to eq('everyone_in_company')
    end
  end

  describe '#call' do
    it 'creates goals with correct owner and default type' do
      service = described_class.new(
        organization, person, teammate, owner_teammate, parsed_goals
      )

      expect { service.call }.to change(Goal, :count).by(3)

      created = Goal.last(3)
      created.each do |goal|
        expect(goal.owner).to eq(owner_teammate)
        expect(goal.creator).to eq(teammate)
        expect(goal.goal_type).to eq('quantitative_key_result')
        expect(goal.privacy_level).to eq('only_creator_owner_and_managers')
        expect(goal.most_likely_target_date).to eq(Date.current + 90.days)
      end
      expect(service.created_goals.size).to eq(3)
      expect(service.errors).to be_empty
    end

    it 'does not create any GoalLinks to an external goal' do
      service = described_class.new(
        organization, person, teammate, owner_teammate, parsed_goals
      )

      expect { service.call }.not_to change(GoalLink, :count)
    end

    it 'creates parent-child GoalLinks when parsed_goals have parent_index' do
      nested_parsed = [
        { title: 'Parent', goal_type: 'inspirational_objective', parent_index: nil },
        { title: 'Child 1', goal_type: 'quantitative_key_result', parent_index: 0 },
        { title: 'Child 2', goal_type: 'quantitative_key_result', parent_index: 0 }
      ]

      service = described_class.new(
        organization, person, teammate, owner_teammate, nested_parsed
      )

      expect { service.call }.to change(Goal, :count).by(3).and change(GoalLink, :count).by(2)

      parent = Goal.find_by(title: 'Parent')
      child1 = Goal.find_by(title: 'Child 1')
      child2 = Goal.find_by(title: 'Child 2')
      expect(parent).to be_present
      expect(child1).to be_present
      expect(child2).to be_present
      expect(GoalLink.find_by(parent: parent, child: child1)).to be_present
      expect(GoalLink.find_by(parent: parent, child: child2)).to be_present
    end

    it 'uses inspirational_objective for dom-with-children from parsed_goals' do
      nested_parsed = [
        { title: 'Objective', goal_type: 'inspirational_objective', parent_index: nil },
        { title: 'Key result', goal_type: 'quantitative_key_result', parent_index: 0 }
      ]

      service = described_class.new(
        organization, person, teammate, owner_teammate, nested_parsed
      )
      service.call

      objective_goal = Goal.find_by(title: 'Objective')
      expect(objective_goal.goal_type).to eq('inspirational_objective')
      expect(objective_goal.most_likely_target_date).to be_nil
    end

    it 'returns false and does not create goals when parsed_goals is empty' do
      service = described_class.new(
        organization, person, teammate, owner_teammate, []
      )

      expect { service.call }.not_to change(Goal, :count)
      expect(service.call).to be false
    end

    it 'works when owner is an Organization' do
      company_owner = organization
      service = described_class.new(
        organization, person, teammate, company_owner, parsed_goals
      )

      expect { service.call }.to change(Goal, :count).by(3)

      created = Goal.last(3)
      created.each do |goal|
        expect(goal.owner_id).to eq(company_owner.id)
        expect(goal.owner_type).to eq('Company')
      end
    end
  end
end
