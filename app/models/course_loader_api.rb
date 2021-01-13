require 'base64'

class CourseLoaderApi

	def initialize
		@errors = []
		@touched_subpages = []
		@tools = CourseTools.new
		@github = Github.new basic_auth: "#{ENV['GITHUB_USERNAME']}:#{ENV['GITHUB_TOKEN']}"
		Rails.logger.debug "HUH"
	end


	# Re-read the course contents from the git repository.
	def run
		
		info = @github.repos.commits.compare base: '5f477c9f314c0175492a034531e1773024507ee1', head: 'master', user: ENV['GITHUB_CONTENT_OWNER'], repo: ENV['GITHUB_CONTENT_REPO']
		puts info.to_json
		puts info.base_commit.sha
		puts info.url
		puts info.permalink_url
		info.files.each do |f|
			Rails.logger.debug "[#{f.status}] #{f.filename} => #{f.previous_filename}"
		end
		return
		
		begin
			# load basic configuration like course name etc
			if config = retrieve_file('course.yml')
				Course.load_course_info(read_config(config))
			end

			# load rules for calculating grades
			if grading = retrieve_file('grading.yml')
				Course.load_course_grading(read_config(grading))
			end

			# load the default schedule in the root of the course folder (if available)
			if contents = retrieve_file('schedule.yml')
				schedule = Schedule.where(name: 'Standard').first_or_create
				schedule.load(read_config(contents))
			end

			# load all schedules in the "schedules" folder (if available)
			list_files('schedules', '.yml').each do |schedule_file|
				schedule_name = upcase_first_if_all_downcase(File.basename(schedule_file, ".*"))
				schedule = Schedule.where(name: schedule_name).first_or_create
				if contents = retrieve_file("schedules/#{schedule_file}")
					schedule.load(read_config(contents))
				end
			end
			
			# load the homepage content from the /info directory
			if files = list_files('info')
				info_page = Page.find_by_path('info') || Page.create(:title => Settings.long_course_name, :position => 0, :path => 'info')
				# load subpages for the homepage
				(list_files('info', '.md') + list_files('info', '.adoc')).each do |file|
					@touched_subpages << Subpage.load(file, retrieve_file("info/#{file}"), info_page)
				end
			end

			# load sections
			list_subdirs('').each do |section_dir|
				section = Section.load(section_dir)
				# load pages in those sections
				list_subdirs(section_dir).each do |page_dir|
					page = Page.load(page_dir, section)
					# load subpages in those pages
					(list_files("#{section_dir}/#{page_dir}", '.md') + list_files("#{section_dir}/#{page_dir}", '.adoc')).each do |file|
						@touched_subpages << Subpage.load(file, retrieve_file("#{section_dir}/#{page_dir}/#{file}"), page)
					end
				end
			end

			# remove old stuff
			@tools.prune_untouched(@touched_subpages)
			@tools.prune_empty
			@tools.recreate_all_slugs
		
			# put psets in order
			CourseTools.clean_psets
		rescue SQLite3::BusyException
			@errors << "A timeout occurred while loading the new course content. Just try again!"
		end
		
		return @errors
	end

	private

	# Reads the config file and returns the contents.
	#
	def read_config(content)
		begin
			return YAML.load(content)
		rescue
			@errors << "A yml was in an unreadable format. Did you confuse tabs and spaces?"
			return nil
		end
	end
	
	def retrieve_file(path)
		begin
			# get it from github
			info = @github.repos.contents.get path: path, user: ENV['GITHUB_CONTENT_OWNER'], repo: ENV['GITHUB_CONTENT_REPO']

			# decode and return
			return Base64.decode64(info.content).force_encoding('UTF-8')
		rescue Github::Error::NotFound
			return nil
		end
	end
	
	def list_files(path, extension=nil)
		# get dir info from github
		list = @github.repos.contents.get path: path, user: ENV['GITHUB_CONTENT_OWNER'], repo: ENV['GITHUB_CONTENT_REPO']
		
		# get only the names from all the info
		names = list.map &:name
		
		# filter by type if needed and return
		extension && names.select { |f| f.end_with?(extension) } || names
	end
	
	def list_subdirs(path)
		# get dir info from github
		list = @github.repos.contents.get path: path, user: ENV['GITHUB_CONTENT_OWNER'], repo: ENV['GITHUB_CONTENT_REPO']

		# get actual directories and then only the names
		list.select { |f| f.type == 'dir' }.map &:name
	end		

	def upcase_first_if_all_downcase(s)
		s == s.downcase && s.sub(/\S/, &:upcase) || s
	end

end
