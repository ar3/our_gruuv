require 'rails_helper'

RSpec.describe DepartmentNameInterpreter do
  let(:company) { create(:organization, type: 'Company', name: 'Acme Corp') }

  describe '#initialize' do
    it 'stores department name and company' do
      interpreter = described_class.new('Engineering', company)
      expect(interpreter.department_name).to eq('Engineering')
      expect(interpreter.company).to eq(company)
    end

    it 'strips whitespace from department name' do
      interpreter = described_class.new('  Engineering  ', company)
      expect(interpreter.department_name).to eq('Engineering')
    end
  end

  describe '#interpret' do
    context 'with blank department name' do
      it 'returns nil' do
        interpreter = described_class.new('', company)
        expect(interpreter.interpret).to be_nil
      end

      it 'returns nil for nil input' do
        interpreter = described_class.new(nil, company)
        expect(interpreter.interpret).to be_nil
      end
    end

    context 'with invalid company' do
      it 'returns nil if company is nil' do
        interpreter = described_class.new('Engineering', nil)
        expect(interpreter.interpret).to be_nil
      end

      it 'returns nil if company is not a Company type' do
        department = create(:organization, type: 'Department', name: 'Dept', parent: company)
        interpreter = described_class.new('Engineering', department)
        expect(interpreter.interpret).to be_nil
      end
    end

    context 'when department name exactly matches company name' do
      it 'returns nil (assignment belongs to company, not a department)' do
        interpreter = described_class.new('Acme Corp', company)
        department = interpreter.interpret

        expect(department).to be_nil
        expect(interpreter.department).to be_nil
      end

      it 'is case-insensitive when matching company name' do
        interpreter = described_class.new('acme corp', company)
        department = interpreter.interpret

        expect(department).to be_nil
      end

      it 'handles whitespace when matching company name' do
        interpreter = described_class.new('  Acme Corp  ', company)
        department = interpreter.interpret

        expect(department).to be_nil
      end
    end

    context 'with single department name (no delimiter)' do
      it 'creates a department under the company' do
        interpreter = described_class.new('Engineering', company)
        department = interpreter.interpret

        expect(department).to be_present
        expect(department.name).to eq('Engineering')
        expect(department.type).to eq('Department')
        expect(department.parent).to eq(company)
      end

      it 'finds existing department if it exists' do
        existing_dept = create(:organization, type: 'Department', name: 'Engineering', parent: company)
        
        interpreter = described_class.new('Engineering', company)
        department = interpreter.interpret

        expect(department.id).to eq(existing_dept.id)
        expect(department.name).to eq(existing_dept.name)
      end

      it 'is case-insensitive when finding existing department' do
        existing_dept = create(:organization, type: 'Department', name: 'Engineering', parent: company)
        
        interpreter = described_class.new('engineering', company)
        department = interpreter.interpret

        expect(department.id).to eq(existing_dept.id)
        expect(department.name).to eq(existing_dept.name)
      end
    end

    context 'with hierarchical department name' do
      context 'when first level matches company name' do
        it 'creates hierarchy: Company > Engineering' do
          interpreter = described_class.new('Acme Corp > Engineering', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('Engineering')
          expect(department.type).to eq('Department')
          expect(department.parent).to eq(company)
        end

        it 'creates hierarchy: Company > Engineering > Backend' do
          interpreter = described_class.new('Acme Corp > Engineering > Backend', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('Backend')
          expect(department.type).to eq('Department')
          
          # Check parent chain
          expect(department.parent.name).to eq('Engineering')
          expect(department.parent.parent).to eq(company)
        end

        it 'creates hierarchy: Company > Sales > North America' do
          interpreter = described_class.new('Acme Corp > Sales > North America', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('North America')
          expect(department.type).to eq('Department')
          
          # Check parent chain
          expect(department.parent.name).to eq('Sales')
          expect(department.parent.parent).to eq(company)
        end

        it 'finds existing departments in hierarchy' do
          engineering = create(:organization, type: 'Department', name: 'Engineering', parent: company)
          backend = create(:organization, type: 'Department', name: 'Backend', parent: engineering)
          
          interpreter = described_class.new('Acme Corp > Engineering > Backend', company)
          department = interpreter.interpret

          expect(department.id).to eq(backend.id)
          expect(department.name).to eq(backend.name)
        end

        it 'creates missing departments in existing hierarchy' do
          engineering = create(:organization, type: 'Department', name: 'Engineering', parent: company)
          
          interpreter = described_class.new('Acme Corp > Engineering > Frontend', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('Frontend')
          expect(department.parent.id).to eq(engineering.id)
        end

        it 'is case-insensitive when matching company name' do
          interpreter = described_class.new('acme corp > Engineering', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('Engineering')
          expect(department.parent).to eq(company)
        end

        it 'handles extra whitespace around delimiters' do
          interpreter = described_class.new('Acme Corp  >  Engineering  >  Backend', company)
          department = interpreter.interpret

          expect(department).to be_present
          expect(department.name).to eq('Backend')
          expect(department.parent.name).to eq('Engineering')
        end
      end

      context 'when first level does not match company name' do
        it 'returns nil and marks as invalid' do
          interpreter = described_class.new('Other Company > Engineering', company)
          department = interpreter.interpret

          expect(department).to be_nil
          expect(interpreter.valid).to be_falsey
          expect(interpreter.error_message).to include("does not match company name")
        end

        it 'is case-insensitive when checking company name match' do
          interpreter = described_class.new('acme corp > Engineering', company)
          department = interpreter.interpret

          # Should work - case-insensitive match
          expect(department).to be_present
          expect(department.name).to eq('Engineering')
          expect(interpreter.valid).to be_truthy
        end

        it 'returns nil when company name is completely different' do
          interpreter = described_class.new('XYZ Inc > Engineering > Backend', company)
          department = interpreter.interpret

          expect(department).to be_nil
          expect(interpreter.valid).to be_falsey
          expect(interpreter.error_message).to include("does not match company name")
        end
      end
    end

    context 'edge cases' do
      it 'handles multiple consecutive delimiters' do
        interpreter = described_class.new('Acme Corp >> Engineering', company)
        department = interpreter.interpret

        # Should treat as single department since first part matches
        expect(department).to be_present
        expect(department.name).to eq('Engineering')
      end

      it 'handles department name that is just the company name' do
        interpreter = described_class.new('Acme Corp', company)
        department = interpreter.interpret

        # When department name matches company name exactly, returns nil
        # (assignment belongs to company, not a department)
        expect(department).to be_nil
        expect(interpreter.department).to be_nil
      end

      it 'handles department name starting with delimiter' do
        interpreter = described_class.new('> Engineering', company)
        department = interpreter.interpret

        # First part is blank, so should treat as single department
        expect(department).to be_present
        expect(department.name).to eq('Engineering')
      end

      it 'handles department name ending with delimiter' do
        interpreter = described_class.new('Acme Corp > Engineering >', company)
        department = interpreter.interpret

        # Last part is blank, should still create Engineering
        expect(department).to be_present
        expect(department.name).to eq('Engineering')
      end
    end

    describe 'return value' do
      it 'returns the department object' do
        interpreter = described_class.new('Engineering', company)
        department = interpreter.interpret

        expect(department).to be_a(Organization)
        expect(department.type).to eq('Department')
      end

      it 'stores the department in the department attribute' do
        interpreter = described_class.new('Engineering', company)
        department = interpreter.interpret

        expect(interpreter.department).to eq(department)
      end
    end
  end

  describe '#preview' do
    context 'with valid department name' do
      it 'returns preview info without creating departments' do
        interpreter = described_class.new('Engineering', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_truthy
        expect(preview[:hierarchy_info]).to be_present
        expect(preview[:hierarchy_info].length).to eq(1)
        expect(preview[:hierarchy_info].first[:name]).to eq('Engineering')
        expect(preview[:hierarchy_info].first[:will_create]).to be_truthy
        expect(preview[:hierarchy_info].first[:department]).to be_nil # Not created yet
      end

      it 'shows existing departments as will_create: false' do
        existing_dept = create(:organization, type: 'Department', name: 'Engineering', parent: company)
        
        interpreter = described_class.new('Engineering', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_truthy
        expect(preview[:hierarchy_info].first[:will_create]).to be_falsey
        expect(preview[:hierarchy_info].first[:existing_id]).to eq(existing_dept.id)
        expect(preview[:hierarchy_info].first[:department].id).to eq(existing_dept.id)
      end

      it 'handles hierarchical departments' do
        interpreter = described_class.new('Acme Corp > Engineering > Backend', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_truthy
        expect(preview[:hierarchy_info].length).to eq(2)
        expect(preview[:hierarchy_info].first[:name]).to eq('Engineering')
        expect(preview[:hierarchy_info].last[:name]).to eq('Backend')
      end

      it 'returns nil department when name matches company' do
        interpreter = described_class.new('Acme Corp', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_truthy
        expect(preview[:department]).to be_nil
        expect(preview[:hierarchy_info]).to be_empty
      end
    end

    context 'with invalid department name' do
      it 'returns invalid when first part does not match company' do
        interpreter = described_class.new('Other Company > Engineering', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_falsey
        expect(preview[:error_message]).to include("does not match company name")
      end

      it 'returns invalid for blank name' do
        interpreter = described_class.new('', company)
        preview = interpreter.preview

        expect(preview[:valid]).to be_falsey
        expect(preview[:error_message]).to include("blank")
      end
    end
  end
end
