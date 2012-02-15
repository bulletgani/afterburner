class ActiveRecord::Base

  include ShardedModel
  include ShardedAssociations
  before_create :set_guid

  def set_guid
    if self.class.SHARDED == true
      (set_user_id && return) if self.class.name == "User"
      self.id = UUID.generate(:compact)
    end
  end

  def set_user_id
    if self.facebook_id
      self.id = "FB_#{self.facebook_id}"
    elsif self.google_id
      self.id = "GOOG_#{self.google_id}"
    elsif self.twitter_id
      self.id = "TWIT_#{self.twitter_id}"
    else
      self.id = "GEN_#{UUID.generate(:compact)}"
    end
  end

end

