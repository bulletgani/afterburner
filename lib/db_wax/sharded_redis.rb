module ShardedRedis

  def self.included(base)
    base.class_eval do
      extend(ClassMethods)
    end
  end

  module ClassMethods
    attr_accessor :clients
    attr_accessor :options
    attr_accessor :shards
    attr_accessor :classname_lower

    def read_config
      options = {}
      self.shards = self.shards || []
      ShardsConfig.read_config
      # establish Redis cache/data/queue connections
      ShardsConfig.CONFIG['redis'].keys.each_with_index do |k, index|
        ShardsConfig.CONFIG['redis'][k]['shards_count'].times do |s|
          db_name = "shard_#{k}_#{s}_#{ENV['RAILS_ENV']}"
          self.shards << db_name.to_sym
          options[db_name.to_sym] = {}
          options[db_name.to_sym][:host] = ShardsConfig.CONFIG['redis'][k][s]['ip']
          options[db_name.to_sym][:port] = ShardsConfig.CONFIG['redis'][k][s]['port']
          options[db_name.to_sym][:db] = s + index*ShardsConfig.CONFIG['redis'][k]['shards_count']
        end
      end
      self.options = options
    end

    def check_shard(shard_name)
      self.clients = self.clients || {}
      self.clients[shard_name] = new(self.options[shard_name]) unless self.clients[shard_name]
      Thread.current["shard_#{self.name}"][shard_name] = self.clients[shard_name]
    end

    def shard_connect(dummy = {})
      self.clients = self.clients || {}
      self.read_config
      self.shards.each do |sh|
        self.clients[sh] = Redis.new(self.options[sh])
      end
      self.clients
    end

    def shard_reset
      Thread.current["shard_#{self.name}"] = self.shard_connect
    end

    def shard_current
      Thread.current["shard_#{self.name}"] || Thread.current["shard_#{self.name}"] = self.shard_connect
    end

    def shard_current=(redis_hash = {})
      Thread.current["shard_#{self.name}"] = redis_hash
    end

    def get_shard_name(type, vbucket)
      id = vbucket % ShardsConfig.CONFIG['redis'][type]['shards_count']
      "shard_#{type}_#{id}_#{::Rails.env}".to_sym
    end

    def using_helper(type, vbucket, command, *options)
      shard_name = self.get_shard_name(type, vbucket)
      if self.shard_current and self.check_shard(shard_name)
        self.clients[shard_name].send(command, *options)
      end
    end

    def using_vb(vbucket, command, *options)
      case command.to_s
        when 'set'
          options[options.size - 1] = Marshal.dump(options[options.size - 1])
        when 'get'
          result = self.using_helper(self.classname_lower, vbucket, command, *options)
          result = Marshal.load(result) if result
          return result
        when 'setraw'      # skip Marshal dump/load
          command = 'set'
        when 'getraw'
          command = 'get'
      end
      return self.using_helper(self.classname_lower, vbucket, command, *options)
    end

    def using(vbucket)
      shard_name = self.get_shard_name(self.classname_lower, vbucket)
      if self.shard_current and self.check_shard(shard_name)
        return self.clients[shard_name]
      end
    end

    def multi(vbucket, &block)
      shard_name = self.get_shard_name(self.classname_lower, vbucket)
      if self.shard_current and self.check_shard(shard_name)
        self.clients[shard_name].client.call :multi
        self.clients[shard_name].instance_eval &block
        self.clients[shard_name].exec
      end
    end
  end
end
