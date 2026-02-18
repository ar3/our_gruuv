require 'rails_helper'

RSpec.describe Assignment, type: :model do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      expect(assignment).to be_valid
    end

    it 'requires a title' do
      assignment.title = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:title]).to include("can't be blank")
    end

    it 'requires a tagline' do
      assignment.tagline = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:tagline]).to include("can't be blank")
    end

    it 'requires a company' do
      assignment.company = nil
      expect(assignment).not_to be_valid
      expect(assignment.errors[:company]).to include("must exist")
    end

    it 'enforces unique titles within the same organization' do
      create(:assignment, title: 'Software Engineer', company: organization)
      duplicate_assignment = build(:assignment, title: 'Software Engineer', company: organization)
      
      expect(duplicate_assignment).not_to be_valid
      expect(duplicate_assignment.errors[:title]).to include('has already been taken')
    end

    it 'allows duplicate titles across different organizations' do
      other_organization = create(:organization)
      create(:assignment, title: 'Software Engineer', company: organization)
      duplicate_assignment = build(:assignment, title: 'Software Engineer', company: other_organization)
      
      expect(duplicate_assignment).to be_valid
    end

    describe 'department_must_belong_to_company' do
      it 'is valid when department belongs to the same company' do
        company = create(:company)
        department = create(:department, company: company)
        assignment = build(:assignment, company: company, department: department)
        expect(assignment).to be_valid
      end

      it 'is invalid when department belongs to a different company' do
        company = create(:company)
        other_company = create(:company)
        department = create(:department, company: other_company)
        assignment = build(:assignment, company: company, department: department)
        expect(assignment).not_to be_valid
        expect(assignment.errors[:department]).to include('must belong to the same company')
      end
    end
  end

  describe 'associations' do
    it 'belongs to a company' do
      expect(assignment.company).to eq(organization)
    end

    it 'has many assignment outcomes' do
      expect(assignment.assignment_outcomes).to be_empty
    end

    it 'has many assignment abilities' do
      expect(assignment.assignment_abilities).to be_empty
    end

    it 'has many abilities through assignment abilities' do
      expect(assignment.abilities).to be_empty
    end

    it 'has one published external reference' do
      expect(assignment.published_external_reference).to be_nil
    end

    it 'has one draft external reference' do
      expect(assignment.draft_external_reference).to be_nil
    end

    it 'has many supplier_supply_relationships' do
      expect(assignment.supplier_supply_relationships).to be_empty
    end

    it 'has many consumer_supply_relationships' do
      expect(assignment.consumer_supply_relationships).to be_empty
    end

    it 'has many consumer_assignments through supplier_supply_relationships' do
      consumer = create(:assignment, company: organization)
      AssignmentSupplyRelationship.create!(
        supplier_assignment: assignment,
        consumer_assignment: consumer
      )
      expect(assignment.consumer_assignments).to include(consumer)
    end

    it 'has many supplier_assignments through consumer_supply_relationships' do
      supplier = create(:assignment, company: organization)
      AssignmentSupplyRelationship.create!(
        supplier_assignment: supplier,
        consumer_assignment: assignment
      )
      expect(assignment.supplier_assignments).to include(supplier)
    end
  end

  describe 'instance methods' do
    it 'returns display name with version' do
      expect(assignment.display_name).to eq("#{assignment.title} v#{assignment.semantic_version}")
    end

    it 'returns company name' do
      expect(assignment.company_name).to eq(organization.display_name)
    end
  end

  describe '#to_s' do
    it 'returns company and assignment title when no department' do
      company = create(:company, name: 'Acme Corp')
      assignment = create(:assignment, company: company, title: 'Product Manager', department: nil)

      expect(assignment.to_s).to eq("Acme Corp > Product Manager v#{assignment.semantic_version}")
    end

    it 'returns company, department, and assignment title when department is set' do
      company = create(:company, name: 'Acme Corp')
      department = create(:department, company: company, name: 'Engineering')
      assignment = create(:assignment, company: company, department: department, title: 'Product Manager')

      expect(assignment.to_s).to eq("Acme Corp > Engineering > Product Manager v#{assignment.semantic_version}")
    end

    it 'returns full department hierarchy when department is nested' do
      company = create(:company, name: 'Acme Corp')
      parent_dept = create(:department, company: company, name: 'Engineering')
      department = create(:department, company: company, parent_department: parent_dept, name: 'Backend')
      assignment = create(:assignment, company: company, department: department, title: 'Product Manager')

      expect(assignment.to_s).to eq("Acme Corp > Engineering > Backend > Product Manager v#{assignment.semantic_version}")
    end
  end

  describe 'archiving' do
    describe '.unarchived and .archived' do
      it 'unarchived returns only assignments with nil deleted_at' do
        a1 = create(:assignment, company: organization, deleted_at: nil)
        a2 = create(:assignment, company: organization, deleted_at: 1.day.ago)
        expect(Assignment.unarchived).to include(a1)
        expect(Assignment.unarchived).not_to include(a2)
      end

      it 'archived returns only assignments with deleted_at set' do
        a1 = create(:assignment, company: organization, deleted_at: nil)
        a2 = create(:assignment, company: organization, deleted_at: 1.day.ago)
        expect(Assignment.archived).to include(a2)
        expect(Assignment.archived).not_to include(a1)
      end
    end

    describe '#archived?' do
      it 'returns false when deleted_at is nil' do
        expect(assignment.archived?).to be false
      end

      it 'returns true when deleted_at is set' do
        assignment.update_columns(deleted_at: 1.day.ago)
        expect(assignment.reload.archived?).to be true
      end
    end

    describe '#archive!' do
      it 'sets deleted_at to current time' do
        assignment.archive!
        expect(assignment.reload.deleted_at).to be_present
        expect(assignment.reload.deleted_at).to be_within(5.seconds).of(Time.current)
      end
    end

    describe '#restore!' do
      it 'clears deleted_at' do
        assignment.update_columns(deleted_at: 1.day.ago)
        assignment.restore!
        expect(assignment.reload.deleted_at).to be_nil
      end
    end

    describe '#archivable?' do
      it 'returns true when no position_assignments and no active assignment_tenures' do
        expect(assignment.archivable?).to be true
      end

      it 'returns false when assignment has position_assignments' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        create(:position_assignment, position: position, assignment: assignment)
        expect(assignment.reload.archivable?).to be false
      end

      it 'returns false when assignment has active assignment_tenures' do
        teammate = create(:teammate, organization: organization)
        create(:assignment_tenure, assignment: assignment, teammate: teammate, started_at: 1.day.ago, ended_at: nil)
        expect(assignment.reload.archivable?).to be false
      end

      it 'returns true when assignment has only ended assignment_tenures' do
        teammate = create(:teammate, organization: organization)
        create(:assignment_tenure, assignment: assignment, teammate: teammate, started_at: 2.days.ago, ended_at: 1.day.ago)
        expect(assignment.reload.archivable?).to be true
      end
    end
  end

  describe 'scopes' do
    describe '.for_company' do
      let(:other_company) { create(:company) }
      let!(:assignment1) { create(:assignment, company: organization) }
      let!(:assignment2) { create(:assignment, company: other_company) }

      it 'returns assignments for specific company' do
        expect(Assignment.for_company(organization)).to include(assignment1)
        expect(Assignment.for_company(organization)).not_to include(assignment2)
      end
    end

    describe '.for_department' do
      let(:department) { create(:department, company: organization) }
      let!(:dept_assignment) { create(:assignment, company: organization, department: department) }
      let!(:no_dept_assignment) { create(:assignment, company: organization, department: nil) }

      it 'returns assignments for specific department' do
        expect(Assignment.for_department(department)).to include(dept_assignment)
        expect(Assignment.for_department(department)).not_to include(no_dept_assignment)
      end
    end
  end

  describe 'ability-related methods' do
    let(:ability1) { create(:ability, company: organization) }
    let(:ability2) { create(:ability, company: organization) }

    describe '#required_abilities' do
      it 'returns abilities ordered by milestone level' do
        create(:assignment_ability, assignment: assignment, ability: ability2, milestone_level: 3)
        create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 1)

        result = assignment.required_abilities
        expect(result.map(&:ability)).to eq([ability1, ability2])
      end
    end

    describe '#required_abilities_count' do
      it 'returns count of required abilities' do
        create(:assignment_ability, assignment: assignment, ability: ability1)
        create(:assignment_ability, assignment: assignment, ability: ability2)

        expect(assignment.required_abilities_count).to eq(2)
      end
    end

    describe '#has_ability_requirements?' do
      it 'returns true when assignment has ability requirements' do
        create(:assignment_ability, assignment: assignment, ability: ability1)
        expect(assignment.has_ability_requirements?).to be true
      end

      it 'returns false when assignment has no ability requirements' do
        expect(assignment.has_ability_requirements?).to be false
      end
    end

    describe '#highest_milestone_for_ability' do
      it 'returns highest milestone level for ability' do
        # Update the existing assignment_ability to have milestone level 4
        assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability1, milestone_level: 2)
        assignment_ability.update!(milestone_level: 4)

        expect(assignment.highest_milestone_for_ability(ability1)).to eq(4)
      end

      it 'returns nil when ability not required' do
        expect(assignment.highest_milestone_for_ability(ability1)).to be_nil
      end
    end

    describe '#add_ability_requirement' do
      it 'adds ability requirement' do
        expect {
          assignment.add_ability_requirement(ability1, 3)
        }.to change(assignment.assignment_abilities, :count).by(1)

        assignment_ability = assignment.assignment_abilities.last
        expect(assignment_ability.ability).to eq(ability1)
        expect(assignment_ability.milestone_level).to eq(3)
      end
    end

    describe '#remove_ability_requirement' do
      it 'removes ability requirement' do
        create(:assignment_ability, assignment: assignment, ability: ability1)

        expect {
          assignment.remove_ability_requirement(ability1)
        }.to change(assignment.assignment_abilities, :count).by(-1)
      end
    end
  end

  describe 'external references' do
    let(:assignment_with_urls) { create(:assignment, :with_source_urls, company: organization) }

    it 'can have published external reference' do
      expect(assignment_with_urls.published_external_reference).to be_present
      expect(assignment_with_urls.published_external_reference.reference_type).to eq('published')
    end

    it 'can have draft external reference' do
      expect(assignment_with_urls.draft_external_reference).to be_present
      expect(assignment_with_urls.draft_external_reference.reference_type).to eq('draft')
    end

    it 'returns published URL' do
      expect(assignment_with_urls.published_url).to eq("https://docs.google.com/document/d/published-example")
    end

    it 'returns draft URL' do
      expect(assignment_with_urls.draft_url).to eq("https://docs.google.com/document/d/draft-example")
    end

    it 'returns nil for missing references' do
      expect(assignment.published_external_reference).to be_nil
      expect(assignment.draft_external_reference).to be_nil
      expect(assignment.published_url).to be_nil
      expect(assignment.draft_url).to be_nil
    end
  end

  describe '#changes_count' do
    before do
      # Enable PaperTrail for these tests
      PaperTrail.enabled = true
    end

    after do
      # Disable PaperTrail after tests to not affect other tests
      PaperTrail.enabled = false
    end

    it 'returns 0 for newly created assignment' do
      # Fresh assignment should have 1 version (creation) but 0 changes
      assignment = create(:assignment, company: organization)
      assignment.reload
      expect(assignment.versions.count).to eq(1)
      expect(assignment.changes_count).to eq(0)
    end

    it 'returns 1 after first update' do
      assignment = create(:assignment, company: organization)
      assignment.update!(title: 'Updated Title')
      assignment.reload
      # Should have 2 versions: creation + 1 update
      expect(assignment.versions.count).to eq(2)
      expect(assignment.changes_count).to eq(1)
    end

    it 'returns 3 after three updates' do
      assignment = create(:assignment, company: organization)
      assignment.update!(title: 'Updated Title 1')
      assignment.update!(tagline: 'Updated Tagline')
      assignment.update!(semantic_version: '1.1.0')
      assignment.reload
      # Should have 4 versions: creation + 3 updates
      expect(assignment.versions.count).to eq(4)
      expect(assignment.changes_count).to eq(3)
    end

    it 'returns correct count after multiple version bumps' do
      assignment = create(:assignment, company: organization, semantic_version: '1.0.0')
      assignment.bump_minor_version  # 1.1.0
      assignment.bump_minor_version  # 1.2.0
      assignment.bump_patch_version  # 1.2.1
      assignment.bump_major_version  # 2.0.0
      assignment.reload
      # Should have 5 versions: creation + 4 version bumps
      expect(assignment.versions.count).to eq(5)
      expect(assignment.changes_count).to eq(4)
    end

    it 'returns 0 when PaperTrail is disabled and no versions exist' do
      PaperTrail.enabled = false
      assignment = Assignment.new(title: 'Test', tagline: 'Test', company: organization)
      assignment.save!(validate: false)
      expect(assignment.versions.count).to eq(0)
      expect(assignment.changes_count).to eq(0)
    end
  end

  describe '#create_outcomes_from_textarea' do
    it 'creates outcomes from textarea input' do
      text = "Increase customer satisfaction by 20%\nReduce response time to under 2 hours\nTeam agrees: We communicate clearly"
      
      assignment.create_outcomes_from_textarea(text)
      
      expect(assignment.assignment_outcomes.count).to eq(3)
      expect(assignment.assignment_outcomes.pluck(:description)).to include(
        'Increase customer satisfaction by 20%',
        'Reduce response time to under 2 hours',
        'Team agrees: We communicate clearly'
      )
    end

    it 'sets quantitative type by default' do
      text = "Increase customer satisfaction by 20%"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('quantitative')
    end

    it 'sets sentiment type when contains agree:' do
      text = "Team agrees: We communicate clearly"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'sets sentiment type when contains agrees:' do
      text = "Team agrees: We work efficiently"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'handles case insensitive detection' do
      text = "Team AGREES: We communicate clearly"
      assignment.create_outcomes_from_textarea(text)
      
      outcome = assignment.assignment_outcomes.first
      expect(outcome.outcome_type).to eq('sentiment')
    end

    it 'ignores empty lines and whitespace' do
      text = "  \nIncrease customer satisfaction\n  \n\nReduce response time\n"
      assignment.create_outcomes_from_textarea(text)
      
      expect(assignment.assignment_outcomes.count).to eq(2)
      expect(assignment.assignment_outcomes.pluck(:description)).to include(
        'Increase customer satisfaction',
        'Reduce response time'
      )
    end

    it 'skips existing outcomes with exact same description' do
      # Create an existing outcome with attributes
      existing = create(:assignment_outcome,
        assignment: assignment,
        description: 'Increase customer satisfaction by 20%',
        outcome_type: 'quantitative',
        management_relationship_filter: 'direct_employee'
      )

      # Process outcomes including the existing one
      text = "Increase customer satisfaction by 20%\nReduce response time to under 2 hours"
      assignment.create_outcomes_from_textarea(text)

      # Should only create the new one, skip the existing
      expect(assignment.assignment_outcomes.count).to eq(2)
      
      # Verify existing outcome was not modified
      existing.reload
      expect(existing.management_relationship_filter).to eq('direct_employee')
    end

    it 'does nothing with blank text' do
      assignment.create_outcomes_from_textarea("")
      assignment.create_outcomes_from_textarea(nil)
      
      expect(assignment.assignment_outcomes.count).to eq(0)
    end
  end

  describe '#to_param' do
    it 'returns id-name-parameterized format based on title' do
      assignment = create(:assignment, company: organization, title: 'Frontend Development')
      expect(assignment.to_param).to eq("#{assignment.id}-frontend-development")
    end

    it 'handles special characters in title' do
      assignment = create(:assignment, company: organization, title: 'Backend & API Development!')
      expect(assignment.to_param).to eq("#{assignment.id}-backend-api-development")
    end
  end

  describe '.find_by_param' do
    let(:assignment) { create(:assignment, company: organization, title: 'Test Assignment') }

    it 'finds by numeric id' do
      expect(Assignment.find_by_param(assignment.id.to_s)).to eq(assignment)
    end

    it 'finds by id-name-parameterized format' do
      param = "#{assignment.id}-test-assignment"
      expect(Assignment.find_by_param(param)).to eq(assignment)
    end

    it 'extracts id from id-name format' do
      param = "#{assignment.id}-some-other-name"
      expect(Assignment.find_by_param(param)).to eq(assignment)
    end

    it 'raises error for invalid id' do
      expect {
        Assignment.find_by_param('999999')
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
