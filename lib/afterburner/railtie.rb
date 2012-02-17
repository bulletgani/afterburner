require 'afterburner'
require 'rails'

module Afterburner
  class Railtie < Rails::Railtie
    railtie_name :afterburner
    rake_tasks do
      #Dir[File.join(File.dirname(__FILE__),'../tasks/*.rb')].each { |f| puts f.inspect; load f }
      load "tasks/afterburner.rb"
    end
  end
end