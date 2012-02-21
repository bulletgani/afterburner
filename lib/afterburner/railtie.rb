require 'afterburner'
require 'rails'
module Afterburner
  class Railtie < Rails::Railtie
    rake_tasks  do
      require 'tasks/afterburner.rb'
    end
  end
end
