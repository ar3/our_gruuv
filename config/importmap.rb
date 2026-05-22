# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
pin "highcharts", to: "https://ga.jspm.io/npm:highcharts@11.3.0/highcharts.js"
pin "cytoscape", to: "https://esm.sh/cytoscape@3.30.4"
pin "vis-data", to: "https://esm.sh/vis-data@7.1.9"
pin "vis-network", to: "https://esm.sh/vis-network@9.1.10"
