class Api::CompaniesController < ApplicationController
  def teams
    company_name = params[:company_name]
    organization = Organization.find_by(name: company_name)

    if organization
      teams = organization.teams.order(:name)
      render json: { teams: teams.map { |team| { name: team.name } } }
    else
      render json: { teams: [] }
    end
  end
end