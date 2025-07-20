class Company < Organization
  # Companies are the top-level organizations
  validates :parent, absence: true
  
  def display_name
    name
  end
end 