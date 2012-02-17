require 'afterburner'
require 'rails'

module Afterburner
  class MyRailtie < Rails::Railtie
    railtie_name :afterburner
    rake_tasks do
      #Dir[File.join(File.dirname(__FILE__),'../tasks/*.rb')].each { |f| puts f.inspect; load f }
      #load "tasks/afterburner.rake"
    end
  end
end