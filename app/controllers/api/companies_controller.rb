class Api::CompaniesController < ApplicationController
  def teams
    company_name = params[:company_name]
    company = Company.find_by(name: company_name)
    
    if company
      teams = company.children.where(type: 'Team').order(:name)
      render json: { teams: teams.map { |team| { name: team.name } } }
    else
      render json: { teams: [] }
    end
  end
end 