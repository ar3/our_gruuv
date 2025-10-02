class Department < Organization
  # Departments must have a parent organization
  validates :parent, presence: true
end
