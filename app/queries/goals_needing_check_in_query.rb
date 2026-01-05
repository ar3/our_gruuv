class GoalsNeedingCheckInQuery
  def initialize(teammate:)
    @teammate = teammate
  end
  
  def call
    # Find goals where:
    # - Goal owner is current user's teammate
    # - Goal is active (not completed, not deleted)
    # - Last check-in is older than 1 week OR no check-in exists
    
    goals = Goal.active
      .where(owner: @teammate)
      .check_in_eligible
    
    goals.select do |goal|
      last_check_in = goal.goal_check_ins.recent.first
      
      if last_check_in.nil?
        # No check-in exists - needs check-in
        true
      else
        # Check if last check-in is older than 1 week
        last_check_in.check_in_week_start < 1.week.ago.beginning_of_week(:monday)
      end
    end
  end
end

