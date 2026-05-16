module CompanyLabelHelper
  def company_label_for(key, default = nil)
    company = current_organization&.root_company || current_organization
    return default || key.to_s.titleize unless company

    company.label_for(key, default)
  end

  def company_label_plural(key, default = nil)
    label = company_label_for(key, default)
    label.pluralize
  end

  def acknowledgement_explanation_markdown(organization = nil)
    org = organization || current_organization
    company = org&.root_company || org
    return Organization::ACKNOWLEDGEMENT_EXPLANATION_DEFAULT unless company

    company.label_for(
      Organization::ACKNOWLEDGEMENT_EXPLANATION_LABEL_KEY,
      Organization::ACKNOWLEDGEMENT_EXPLANATION_DEFAULT
    )
  end
end
