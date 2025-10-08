# Pagy configuration
require 'pagy/extras/bootstrap'
require 'pagy/extras/items'

# Set default items per page
Pagy::DEFAULT[:items] = 25

# Set maximum items per page
Pagy::DEFAULT[:max_items] = 100

# Enable Bootstrap styling
Pagy::DEFAULT[:bootstrap] = true

# Set pagination size (how many page links to show)
Pagy::DEFAULT[:size] = [1,4,4,1] # nav bar links: prev, pages, next

# Set page parameter name
Pagy::DEFAULT[:page_param] = :page
