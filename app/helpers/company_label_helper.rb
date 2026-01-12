module CompanyLabelHelper
  def company_label_for(key, default = nil)
    company = current_organization&.root_company || current_organization
    return default || key.to_s.titleize unless company
    
    # Only call label_for on Company instances
    return default || key.to_s.titleize unless company.is_a?(Company)
    
    company.label_for(key, default)
  end

  def company_label_plural(key, default = nil)
    label = company_label_for(key, default)
    label.pluralize
  end
end
