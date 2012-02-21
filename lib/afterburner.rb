require 'afterburner/version'

module Afterburner

  class Railtie < Rails::Railtie
    railtie_name :afterburner
    rake_tasks  do
      load 'tasks/afterburner.rake'
    end
  end

end

REF = -1

require 'afterburner/shards_config'
require 'afterburner/sharded_model'
require 'afterburner/sharded_associations'
require 'afterburner/sharded_redis'
require 'afterburner/vbucket_setup'
require 'afterburner/ar_extensions'
require 'afterburner/acts_as_locally_cached'
require 'afterburner/analytics'

