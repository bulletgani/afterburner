require "yaml"
require "erb"

module Afterburner

  class << self
    attr_accessor :VBUCKET_COUNT
    attr_accessor :SHARDS_CONFIG
    attr_accessor :REF_VBUCKET
  end

  def self.directory()
    @directory ||= defined?(Rails) ?  Rails.root.to_s : Dir.pwd
  end

  def self.shards_config
    unless self.SHARDS_CONFIG
      self.REF_VBUCKET = -1
      self.SHARDS_CONFIG = {}
      shard_yml = YAML::load(ERB.new(IO.read(Afterburner.directory() + "/config/environments/#{::Rails.env}_shards.yml")).result)
      shard_yml = YAML::load(ERB.new(IO.read("config/environments/#{::Rails.env}_shards.yml")).result)
      # Virtual bucket
      # Every sharded entry falls into exactly one bucket
      # A given set of buckets in each environment is mapped to a database based on SHARDS_COUNT
      # Why 720  ?
      #   because it is the LCM of 1,2,3,4,6,8,10,12,16,20,24,30,40 => easy migration to SHARDS_COUNT
      self.VBUCKET_COUNT = shard_yml['vbucket_count'].to_i || 720

      ['db', 'redis'].each do |type|
        self.SHARDS_CONFIG[type]={}
        shard_yml[type].keys.each do |k|
          if k != 'master'
            self.SHARDS_CONFIG[type][k] = {}
            self.SHARDS_CONFIG[type][k]['shards_count'] = shard_yml[type][k]['shards_count'].to_i
            self.SHARDS_CONFIG[type][k]['shards_count'].times do |i|
              self.SHARDS_CONFIG[type][k][i] = {}
              self.SHARDS_CONFIG[type][k][i]['ip'] = shard_yml[type][k][i]['ip'] || 'localhost'
              self.SHARDS_CONFIG[type][k][i]['port'] = shard_yml[type][k][i]['port'] || 3369
              self.SHARDS_CONFIG[type][k][i]['username'] = shard_yml[type][k][i]['username'] || 'root'
              self.SHARDS_CONFIG[type][k][i]['password'] = shard_yml[type][k][i]['password'] || ''
            end
          elsif k == 'master'
            self.SHARDS_CONFIG[type][k] = {}
            self.SHARDS_CONFIG[type][k]['ip'] = shard_yml[type][k]['ip'] || 'localhost'
            self.SHARDS_CONFIG[type][k]['port'] = shard_yml[type][k]['port'] || 3369
            self.SHARDS_CONFIG[type][k]['username'] = shard_yml[type][k]['username'] || 'root'
            self.SHARDS_CONFIG[type][k]['password'] = shard_yml[type][k]['password'] || ''
          end
        end
      end
    end
    self.SHARDS_CONFIG
  end
end
