class HealthcheckController < ApplicationController
  def index
    @person_count = Person.count rescue "DB ERROR"
  end
end
