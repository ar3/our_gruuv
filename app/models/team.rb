class Team < Organization
  # Teams must have a parent organization
  validates :parent, presence: true
end 