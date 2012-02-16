module ShardedAssociations

  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods

    def belongs_to_sharded(object, *options)
      define_method object.to_sym, lambda {
        obj = object.to_s.camelize.constantize
        result = obj.using_vb(obj.SHARDED == true ? self.vbucket : REF, :find_by_id, self.send(object.to_s.foreign_key))
        return result
      }
    end

    def has_many_sharded(objects, options = {}, &extension)
      has_many objects, options, &extension
    end

=begin
    def has_many_sharded(objects, options = {}, &extension)
      define_method objects.to_sym, lambda { |find_opts={}|
        obj = objects.to_s.singularize.camelize.constantize
        options.merge!(find_opts)
        options.merge!(self.class.to_s.foreign_key.to_sym => self.id)
        obj.using_vb(obj.SHARDED == true ? self.vbucket : REF, :where, options)
      }
    end
=end

=begin
    def has_many_sharded(objects, *options)
      has_many objects, *options
    end


    def has_many_sharded(objects, *options)
>>>>>>> sprint_20
      define_method objects.to_sym, lambda {
        obj = objects.to_s.singularize.camelize.constantize
        options.merge!(self.class.to_s.foreign_key.to_sym => self.id)
        obj.using_vb(obj.SHARDED == true ? self.vbucket : REF, :where, options)
        #self.connection.current_shard = self.current_shard
        #Octopus.using(self.class.get_shard_name(self.class.SHARDED == true ? self.vbucket : REF)) {obj.where(options)}
      }
    end
=begin

    def has_many_sharded association_id, options = {}, &extension
      has_many association_id, options = {}, &extension
    end


    def belongs_to_sharded(object, *options)
      belongs_to object, *options
    end

=end

  end
end
