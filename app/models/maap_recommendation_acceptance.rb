# frozen_string_literal: true

class MaapRecommendationAcceptance < ApplicationRecord
  belongs_to :maap_agent_run
  belongs_to :teammate, class_name: 'CompanyTeammate'

  validates :recommendation_id, presence: true
end
