require 'afterburner'
require 'rails'

module Afterburner
  class Railtie < Rails::Railtie
    railtie_name :afterburner
    rake_tasks do
      load "tasks/afterburner.rake"
    end
  end
end
