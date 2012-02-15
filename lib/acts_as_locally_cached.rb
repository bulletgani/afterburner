module ActsAsLocallyCached

  def self.included(base)
    base.extend(ClassMethods)
    base.send(:update_local_ref_cache_timestamp)
  end


  module ClassMethods

    attr_accessor :local_ref_cache
    attr_accessor :local_ref_cache_timestamp

    def sync_local_cache
      self.populate_cache(true)
    end

    def populate_cache(sync_with_db = false)
      must_sync = self.local_ref_cache == {} or self.local_ref_cache_timestamp.nil? or self.local_ref_cache.blank?
      if sync_with_db or must_sync
        cache_control = Item.using_vb(REF, :first).updated_at unless must_sync
        if must_sync or self.local_ref_cache_timestamp != cache_control
          self.local_ref_cache = {}
          self.local_ref_cache_timestamp = cache_control
          self.using_vb(REF, :all).each do |obj|
            self.local_ref_cache.merge!(obj.id.to_s => obj)
          end
        end
      end
    end

    def id_array_to_obj_array(obj_id_array = [])
      self.populate_cache
      obj_arr = []
      obj_id_array.each do |i|
        item = local_ref_cache[i]
        if item.blank?
          ::Rails.logger.error "CHECK ME NOW.... Tried to add invalid item_id=#{i} for user=#{ApiResponse.current.current_user.inspect}"
        else
          obj_arr << item unless item.blank?
        end
      end
      obj_arr
    end

    def id_list_to_obj_array(obj_id_list = '')
      return [] if obj_id_list.blank?
      id_array_to_obj_array(obj_id_list.split(','))
    end

    def id_to_obj(obj_id)
      return nil if obj_id.blank?
      self.populate_cache
      self.local_ref_cache[obj_id] unless self.local_ref_cache.blank?
    end

    def all_objs
      self.populate_cache
      self.local_ref_cache
    end

    def update_local_ref_cache_timestamp
      # make sure to save record without callbacks
      self.using_vb(REF, :first).update_column(:updated_at, Time.now)
    end
  end

end

