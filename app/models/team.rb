class Team < Organization
  # Teams must have a parent organization
  validates :parent, presence: true
  
  def display_name
    "#{parent.name} - #{name}"
  end
end 