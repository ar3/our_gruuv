# Pagy configuration
require 'pagy/extras/bootstrap'
require 'pagy/extras/items'

# Set default items per page
Pagy::DEFAULT[:items] = 25

# Set maximum items per page
Pagy::DEFAULT[:max_items] = 100

# Enable Bootstrap styling
Pagy::DEFAULT[:bootstrap] = true
