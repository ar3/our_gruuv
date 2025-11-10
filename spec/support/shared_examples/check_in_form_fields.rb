RSpec.shared_examples "position check-in form fields" do |view_type|
  it "renders identical position form fields for #{view_type} view" do
    sign_in_as(user, organization)
    visit organization_person_check_ins_path(organization, employee, view: view_type)
    
    # Position fields should be present
    expect(page).to have_css('select[name*="position_check_in"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="position_check_in"][name*="manager_private_notes"]')
    expect(page).to have_css('input[name*="position_check_in"][name*="status"][type="radio"]')
    
    # Should have both draft and complete radio options
    expect(page).to have_css('input[name*="position_check_in"][name*="status"][value="draft"]')
    expect(page).to have_css('input[name*="position_check_in"][name*="status"][value="complete"]')
  end
end

RSpec.shared_examples "assignment check-in form fields" do |view_type|
  it "renders identical assignment form fields for #{view_type} view" do
    sign_in_as(user, organization)
    visit organization_person_check_ins_path(organization, employee, view: view_type)
    
    # Assignment fields should be present
    expect(page).to have_css('select[name*="assignment_check_ins"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]')
    expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][type="radio"]')
    
    # Should have both draft and complete radio options
    expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="draft"]')
    expect(page).to have_css('input[name*="assignment_check_ins"][name*="status"][value="complete"]')
  end
end

RSpec.shared_examples "aspiration check-in form fields" do |view_type|
  it "renders identical aspiration form fields for #{view_type} view" do
    sign_in_as(user, organization)
    visit organization_person_check_ins_path(organization, employee, view: view_type)
    
    # Aspiration fields should be present
    expect(page).to have_css('select[name*="aspiration_check_ins"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]')
    expect(page).to have_css('input[name*="aspiration_check_ins"][name*="status"][type="radio"]')
    
    # Should have both draft and complete radio options
    expect(page).to have_css('input[name*="aspiration_check_ins"][name*="status"][value="draft"]')
    expect(page).to have_css('input[name*="aspiration_check_ins"][name*="status"][value="complete"]')
  end
end

RSpec.shared_examples "employee check-in form fields" do |view_type|
  it "renders identical employee form fields for #{view_type} view" do
    sign_in_as(employee, organization)
    visit organization_person_check_ins_path(organization, employee, view: view_type)
    
    # Employee-specific fields (no manager fields should be visible)
    expect(page).to have_css('select[name*="position_check_in"][name*="employee_rating"]')
    expect(page).to have_css('textarea[name*="position_check_in"][name*="employee_private_notes"]')
    
    expect(page).to have_css('select[name*="assignment_check_ins"][name*="employee_rating"]')
    expect(page).to have_css('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]')
    
    expect(page).to have_css('select[name*="aspiration_check_ins"][name*="employee_rating"]')
    expect(page).to have_css('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]')
    
    # Should NOT have manager fields for any check-in type
    expect(page).not_to have_css('select[name*="position_check_in"][name*="manager_rating"]')
    expect(page).not_to have_css('textarea[name*="position_check_in"][name*="manager_private_notes"]')
    expect(page).not_to have_css('select[name*="assignment_check_ins"][name*="manager_rating"]')
    expect(page).not_to have_css('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]')
    expect(page).not_to have_css('select[name*="aspiration_check_ins"][name*="manager_rating"]')
    expect(page).not_to have_css('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]')
    
    # Should NOT have manager assessment section headers
    expect(page).not_to have_content('Manager Assessment')
  end
end

RSpec.shared_examples "manager check-in form fields" do |view_type|
  it "renders identical manager form fields for #{view_type} view" do
    sign_in_as(manager, organization)
    visit organization_person_check_ins_path(organization, employee, view: view_type)
    
    # Manager-specific fields (no employee fields should be visible)
    expect(page).to have_css('select[name*="position_check_in"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="position_check_in"][name*="manager_private_notes"]')
    
    expect(page).to have_css('select[name*="assignment_check_ins"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="assignment_check_ins"][name*="manager_private_notes"]')
    
    expect(page).to have_css('select[name*="aspiration_check_ins"][name*="manager_rating"]')
    expect(page).to have_css('textarea[name*="aspiration_check_ins"][name*="manager_private_notes"]')
    
    # Should NOT have employee fields for any check-in type
    expect(page).not_to have_css('select[name*="position_check_in"][name*="employee_rating"]')
    expect(page).not_to have_css('textarea[name*="position_check_in"][name*="employee_private_notes"]')
    expect(page).not_to have_css('select[name*="assignment_check_ins"][name*="employee_rating"]')
    expect(page).not_to have_css('textarea[name*="assignment_check_ins"][name*="employee_private_notes"]')
    expect(page).not_to have_css('input[name*="assignment_check_ins"][name*="actual_energy_percentage"]')
    expect(page).not_to have_css('select[name*="assignment_check_ins"][name*="employee_personal_alignment"]')
    expect(page).not_to have_css('select[name*="aspiration_check_ins"][name*="employee_rating"]')
    expect(page).not_to have_css('textarea[name*="aspiration_check_ins"][name*="employee_private_notes"]')
    
    # Should NOT have employee assessment section headers
    expect(page).not_to have_content('Employee Assessment')
  end
end




