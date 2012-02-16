Afterburner.SHARDS_CONFIG['redis'].keys.each do |key|
  klass = Object.const_set("Redis#{key.capitalize}", Class.new)
  klass.class_eval do
    include ShardedRedis
    self.classname_lower = key
  end
end