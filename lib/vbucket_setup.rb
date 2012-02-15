module VbucketSetup

  def get_vbucket(id=nil)
    id = get_shard_key(id) if id.nil?
    Digest::MD5.hexdigest(id.to_s).gsub(/[a-z]/i) { |s| s.ord.to_s }.to_i % VBUCKET_COUNT
  end

  def get_shard_key(id = nil)
    return id unless id.blank?
    if session[:current_user_facebook_id]
      return "FB_#{session[:current_user_facebook_id].to_s}"
    elsif params[:signed_request]
      fb_id = OauthController.get_signed_request_json(params[:signed_request])['user_id']
      return "FB_#{fb_id.to_s}"
    elsif session[:current_user_twitter_id]
    elsif session[:current_user_google_id]

    end
  end

end