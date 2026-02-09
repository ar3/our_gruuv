# frozen_string_literal: true

class ObserveWorkAnniversariesJob < ApplicationJob
  queue_as :default

  def perform(organization_id = nil)
    if organization_id
      org = Organization.find(organization_id)
      ObservableMoments::ObserveWorkAnniversariesService.call(organization: org)
    else
      total = { created: 0 }
      Organization.find_each do |org|
        result = ObservableMoments::ObserveWorkAnniversariesService.call(organization: org)
        total[:created] += result[:created]
      end
      total
    end
  end
end
