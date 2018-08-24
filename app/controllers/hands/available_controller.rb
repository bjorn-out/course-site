class Hands::AvailableController < ApplicationController

	before_filter CASClient::Frameworks::Rails::Filter
	before_filter :require_staff

	def index
		@user = current_user
		real_time = DateTime.now
		cutoff_time = real_time.beginning_of_hour
		@option1 = cutoff_time + 1.hours
		@optionU = 1.hour.ago
		@available = ((@user.available or DateTime.now) > DateTime.now)
		@available_string = @available ? "" : "not"
	end
	
	def set
		current_user.update_attribute(:available, params[:until])
		redirect_to hands_path
	end

end
