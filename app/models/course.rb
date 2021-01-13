class Course

	### Load basic info from course.yml
	###
	def self.load_course_info(source)
		if config = source
			if config['course']
				Settings['long_course_name'] = config['course']['title'] if config['course']['title']
				Settings['short_course_name'] = config['course']['short'] if config['course']['short']
				Settings['submit_directory'] = config['course']['submit'] if config['course']['submit']
				Settings['mail_address'] = config['course']['mail']
				Settings['hands_allow'] = config['ask']['hands'] if config['ask']
				Settings['hands_slack_channel'] = config['ask']['slack'] if config['ask']
			end
			Settings['display_acknowledgements'] = config['acknowledgements'] if config['acknowledgements']
			Settings['display_license'] = config['license'] if config['license']
			Settings['cdn_prefix'] = config['cdn'] if config['cdn']
			Settings['psets'] = config['psets'] if config['psets']
			Settings['links'] = config['links'] if config['links']
			Settings['submodule'] = config['submodule'] if config['submodule']
		else
			@errors << "You do not have a course.yml!"
		end
	end
	
	### Load grading.yml into setting
	###
	def self.load_course_grading(source)
		if grading = source
			Settings['grading'] = grading
		end
	end	

end
