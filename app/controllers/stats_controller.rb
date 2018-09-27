class StatsController < ApplicationController

	before_filter CASClient::Frameworks::Rails::Filter
	before_filter :require_admin
	
	def hands
		@today = Hand.includes(:assist).where("created_at > ?", DateTime.yesterday.beginning_of_day).order("created_at desc")
		
		@chart_data = Hand.joins(:assist).where("hands.created_at > ? and hands.done = ?", Date.today.beginning_of_day, true).order("hands.created_at desc").group_by(&:assist).map do |assist, hands|
			hands.map do |hand|
				[assist.name, hand.claimed_at, hand.updated_at]
			end
		end
		
		@chart_data = @chart_data.flatten(1)
	end

end
