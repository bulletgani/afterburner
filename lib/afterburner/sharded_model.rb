module ShardedModel

  def self.included(base)
    base.extend(ClassMethods)
  end


  module ClassMethods

    # needed to tell User.using that it is a model_shard
    attr_accessor :SHARDED
    attr_accessor :MODEL_SHARD


    def get_vbucket(id)
      Digest::MD5.hexdigest(id).gsub(/[a-z]/i) { |s| s.ord.to_s }.to_i % Afterburner.VBUCKET_COUNT
    end


    def using_vb(vbucket, *options)
      begin
        shard_name = ''
        raise "incompatible setting for SHARDED variable in class or instance #{self.inspect}" if (REF == vbucket and self.SHARDED == true) or (REF != vbucket and self.SHARDED.nil?)
        shard_name = get_shard_name(vbucket)
        return self.using(shard_name).send(*options)
      rescue Exception => e
        if self.class.name == "Asset"
          Octopus.using(:master) do
            return self.first
          end
        end
        raise e
      end
    end

    def all_shards_helper(type, *options)
      # this is operation on all shards
      result = []
      # brute force for now .... optimize later
      shard_name = ''
      shard_count = Afterburner.SHARDS_CONFIG['db']['generic']['shards_count']
      if self.MODEL_SHARD == true
        shard_name = self.name.underscore+'_'
        shard_count = Afterburner.SHARDS_CONFIG['db'][self.name.underscore]['shards_count']
      end
      shard_count.times do |s|
        if type == :each
          result << self.using("shard_#{shard_name+s.to_s}_#{::Rails.env}".to_sym).send(*options)
        else
          temp_var = self.using("shard_#{shard_name+s.to_s}_#{::Rails.env}".to_sym).send(*options)
          if !temp_var.instance_of?(Array)
            result += [self.using("shard_#{shard_name+s.to_s}_#{::Rails.env}".to_sym).send(*options)]
          else
            result += self.using("shard_#{shard_name+s.to_s}_#{::Rails.env}".to_sym).send(*options)
          end
        end
      end
      # we have an array or arrays
      result
    end

    def in_each_shard(*options)
      all_shards_helper(:each, *options)
    end


    def in_all_shards(*options)
      all_shards_helper(:all, *options)
    end

    def in_each_db(*options)
      result = {}
      result['master'] = self.using(get_shard_name(REF)).send(*options)
      Afterburner.SHARDS_CONFIG['db'].keys.each do |key|
        next if key == 'master'
        result[key] = {}
        Afterburner.SHARDS_CONFIG['db'][key]['shards_count'].times do |c|
          shard_name = key == 'generic' ? c.to_s : "#{key}_#{c}"
          result[key][c] = self.using("shard_#{shard_name}_#{::Rails.env}".to_sym).send(*options)
        end
      end
      result
    end

    def get_shard_name(vbucket)
      return :master if ENV['SINGLE_SHARD'].to_s == 'true'
      shard_count = Afterburner.SHARDS_CONFIG['db']['generic']['shards_count']
      if vbucket != REF
        shard_id = ''
        if self.class == Class.class
          # in class method =>
          if self.MODEL_SHARD
            shard_id = self.name.underscore
            shard_count = Afterburner.SHARDS_CONFIG['db'][shard_id]['shards_count']
            shard_id = "#{shard_id}_"
          end
        else
          # in instance method
          if self.class.MODEL_SHARD
            shard_id = self.class.name.underscore
            shard_count = Afterburner.SHARDS_CONFIG['db'][shard_id]['shards_count']
            shard_id = "#{shard_id}_"
          end
        end
        shard_name = "#{shard_id}#{vbucket%shard_count}"
        return "shard_#{shard_name}_#{::Rails.env}".to_sym
      else
        return :master
      end
    end
  end

  def check_vbucket
    unless self.vbucket
      self.vbucket = self.class.get_vbucket(self.class.name == User.name ? "FB_#{self.facebook_id}" : self.user_id)
    end
  end

  def my_vbucket
    self.class.SHARDED == true ? self.vbucket : REF
  end

end
