class GradesController < ApplicationController

	before_action :authorize
	before_action :require_staff
	before_action :set_grade

	def publish
		@grade.published!
		redirect_to @grade.submit
	end

	def reopen
		@grade.unfinished!
		redirect_to @grade.submit
	end

	def reject
		@grade.update(grade:0)
		@grade.published!
		@submit = @grade.submit
		redirect_js location: submit_path(@submit)
	end

	def destroy
		@submit = @grade.submit
		@grade.destroy
		redirect_to submit_path(@submit)
	end

	private

	def set_grade
		@grade = Grade.find(params[:id])
	end

end
