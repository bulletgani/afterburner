if ['test', 'cucumber'].include? ::Rails.env
  require 'factory_girl'
  require "#{Rails.root}/spec/factories"

  class Factory
    attr_accessor :options

    def self.get_class_from_name(name)
      klass = factory_by_name(name)
      if klass.options[:class].nil?
        klass = klass.factory_name.to_s.camelize.constantize
      else
        klass = klass.options[:class].to_s.camelize.constantize
      end
      klass
    end

    def self.shard_create(*options)
      klass = get_class_from_name(options[0])
      vbkt = REF
      op = nil
      if klass.name == User.name
        user_id = nil
        # case 1) user_id is passed
        if !(options.size > 1 and !options[1][:facebook_id].nil?)
          u = Factory.build(:user)
          options << {} if options.size == 1
          options[1][:facebook_id] = u.facebook_id
          user_id = "FB_#{u.facebook_id}"
        else
          user_id = "FB_#{options[1][:facebook_id]}"
        end
        vbkt = klass.get_vbucket(user_id)
      else
        vbkt = klass.get_vbucket(options[1][:user_id])
      end if klass.SHARDED == true
      Octopus.using(klass.get_shard_name(vbkt)) do
        op = Factory.create(*options)
      end
      return op
    end

  end

end
