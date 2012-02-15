

# Load the rails application
require File.expand_path('../app', __FILE__)
require 'shards_config'
require 'active_record_helper'
require 'sharded_model'
require 'sharded_associations'
require 'sharded_redis'


if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    # Only works with DalliStore
    #Rails.cache.reset if forked
    if forked
      UUID.generator.next_sequence
      RedisCache.shard_reset
      RedisData.shard_reset
      RedisQueue.shard_reset
    end
  end
end


env = ENV['RAILS_ENV']
db_yml = YAML::load(ERB.new(IO.read("config/database.yml")).result)
shards_yml = YAML::load(ERB.new(IO.read("config/shards.yml")).result)
reference = shards_yml['octopus'][env]['shards']
reference = db_yml.merge reference
ActiveRecord::Base.configurations = reference.dup
