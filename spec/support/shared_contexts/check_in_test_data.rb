RSpec.shared_context 'check_in_test_data' do
  # Company with 3 departments
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:sales_department) { create(:organization, :department, name: 'Sales', parent: company) }
  let(:product_department) { create(:organization, :department, name: 'Product', parent: company) }
  let(:support_department) { create(:organization, :department, name: 'Support', parent: company) }

  # 4 company-level aspirations
  let(:company_aspiration_1) { create(:aspiration, organization: company, name: 'Company Growth', sort_order: 1) }
  let(:company_aspiration_2) { create(:aspiration, organization: company, name: 'Innovation', sort_order: 2) }
  let(:company_aspiration_3) { create(:aspiration, organization: company, name: 'Customer Satisfaction', sort_order: 3) }
  let(:company_aspiration_4) { create(:aspiration, organization: company, name: 'Team Development', sort_order: 4) }

  # 1 aspiration per department
  let(:sales_aspiration) { create(:aspiration, organization: sales_department, name: 'Sales Excellence', sort_order: 1) }
  let(:product_aspiration) { create(:aspiration, organization: product_department, name: 'Product Innovation', sort_order: 1) }
  let(:support_aspiration) { create(:aspiration, organization: support_department, name: 'Customer Support', sort_order: 1) }

  # Position major level and levels
  let(:position_major_level) { create(:position_major_level) }
  let(:position_level_1) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
  let(:position_level_2) { create(:position_level, position_major_level: position_major_level, level: '2.0') }
  let(:position_level_3) { create(:position_level, position_major_level: position_major_level, level: '3.0') }
  let(:position_level_4) { create(:position_level, position_major_level: position_major_level, level: '4.0') }

  # 1 position type for company + 1 per department
  let(:company_title) { create(:title, organization: company, external_title: 'Company Manager', position_major_level: position_major_level) }
  let(:sales_title) { create(:title, organization: sales_department, external_title: 'Sales Rep', position_major_level: position_major_level) }
  let(:product_title) { create(:title, organization: product_department, external_title: 'Product Manager', position_major_level: position_major_level) }
  let(:support_title) { create(:title, organization: support_department, external_title: 'Support Specialist', position_major_level: position_major_level) }

  # 1 position per position type
  let(:company_position) { create(:position, title: company_title, position_level: position_level_1) }
  let(:sales_position) { create(:position, title: sales_title, position_level: position_level_2) }
  let(:product_position) { create(:position, title: product_title, position_level: position_level_3) }
  let(:support_position) { create(:position, title: support_title, position_level: position_level_4) }

  # 3 company-level assignments
  let(:company_assignment_1) { create(:assignment, company: company, title: 'Company Strategy', tagline: 'Drive company-wide strategic initiatives') }
  let(:company_assignment_2) { create(:assignment, company: company, title: 'Company Operations', tagline: 'Manage day-to-day company operations') }
  let(:company_assignment_3) { create(:assignment, company: company, title: 'Company Culture', tagline: 'Foster positive company culture') }

  # 3 assignments per department
  let(:sales_assignment_1) { create(:assignment, company: company, department: sales_department, title: 'Sales Growth', tagline: 'Drive sales growth initiatives') }
  let(:sales_assignment_2) { create(:assignment, company: company, department: sales_department, title: 'Customer Acquisition', tagline: 'Acquire new customers') }
  let(:sales_assignment_3) { create(:assignment, company: company, department: sales_department, title: 'Sales Training', tagline: 'Train sales team members') }

  let(:product_assignment_1) { create(:assignment, company: company, department: product_department, title: 'Product Development', tagline: 'Develop new products') }
  let(:product_assignment_2) { create(:assignment, company: company, department: product_department, title: 'Product Strategy', tagline: 'Define product strategy') }
  let(:product_assignment_3) { create(:assignment, company: company, department: product_department, title: 'Product Research', tagline: 'Conduct product research') }

  let(:support_assignment_1) { create(:assignment, company: company, department: support_department, title: 'Customer Support', tagline: 'Provide excellent customer support') }
  let(:support_assignment_2) { create(:assignment, company: company, department: support_department, title: 'Support Documentation', tagline: 'Create support documentation') }
  let(:support_assignment_3) { create(:assignment, company: company, department: support_department, title: 'Support Training', tagline: 'Train support team members') }

  # Manager person attached to company position
  let(:manager) { create(:person, first_name: 'Manager', last_name: 'Person', email: 'manager@example.com') }
  let(:manager_teammate) { create(:teammate, person: manager, organization: company, can_manage_employment: true) }
  let(:manager_employment) { create(:employment_tenure, teammate: manager_teammate, company: company, position: company_position, manager: nil) }

  # 4 employee persons (one per position)
  let(:company_employee) { create(:person, first_name: 'Company', last_name: 'Employee', email: 'company@example.com') }
  let(:company_employee_teammate) { create(:teammate, person: company_employee, organization: company) }
  let(:company_employee_employment) { create(:employment_tenure, teammate: company_employee_teammate, company: company, position: company_position, manager: manager) }

  let(:sales_employee) { create(:person, first_name: 'Sales', last_name: 'Employee', email: 'sales@example.com') }
  let(:sales_employee_teammate) { create(:teammate, person: sales_employee, organization: sales_department) }
  let(:sales_employee_employment) { create(:employment_tenure, teammate: sales_employee_teammate, company: company, position: sales_position, manager: manager) }

  let(:product_employee) { create(:person, first_name: 'Product', last_name: 'Employee', email: 'product@example.com') }
  let(:product_employee_teammate) { create(:teammate, person: product_employee, organization: product_department) }
  let(:product_employee_employment) { create(:employment_tenure, teammate: product_employee_teammate, company: company, position: product_position, manager: manager) }

  let(:support_employee) { create(:person, first_name: 'Support', last_name: 'Employee', email: 'support@example.com') }
  let(:support_employee_teammate) { create(:teammate, person: support_employee, organization: support_department) }
  let(:support_employee_employment) { create(:employment_tenure, teammate: support_employee_teammate, company: company, position: support_position, manager: manager) }

  # Setup all the data
  before do
    # Create all the basic data
    company
    sales_department
    product_department
    support_department
    
    # Create aspirations
    company_aspiration_1
    company_aspiration_2
    company_aspiration_3
    company_aspiration_4
    sales_aspiration
    product_aspiration
    support_aspiration
    
    # Create position types and positions
    company_title
    sales_title
    product_title
    support_title
    company_position
    sales_position
    product_position
    support_position
    
    # Create assignments
    company_assignment_1
    company_assignment_2
    company_assignment_3
    sales_assignment_1
    sales_assignment_2
    sales_assignment_3
    product_assignment_1
    product_assignment_2
    product_assignment_3
    support_assignment_1
    support_assignment_2
    support_assignment_3
    
    # Create manager and employees
    manager
    manager_teammate
    manager_employment
    company_employee
    company_employee_teammate
    company_employee_employment
    sales_employee
    sales_employee_teammate
    sales_employee_employment
    product_employee
    product_employee_teammate
    product_employee_employment
    support_employee
    support_employee_teammate
    support_employee_employment
  end
end
