class PublicMaap::IndexController < ApplicationController
  layout 'public_maap'
  
  def index
    # Find all companies that have MAAP content
    # A company has content if it has at least one position, assignment, ability, or aspiration
    company_ids_with_content = []
    
    # Companies with positions (Title belongs_to :company)
    company_ids_with_content += Position
      .joins(title: :company)
      .pluck('organizations.id')
    
    # Companies with assignments
    company_ids_with_content += Assignment
      .joins(:company)
      .pluck('organizations.id')
    
    # Companies with abilities
    company_ids_with_content += Ability
      .joins(:company)
      .pluck('organizations.id')
    
    # Companies with aspirations
    company_ids_with_content += Aspiration.joins(:company)
      .pluck('organizations.id')
    
    @companies = Organization.where(id: company_ids_with_content.uniq).order(:name)
  end
end


