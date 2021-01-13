require 'course_git'

class CourseLoader
	
	# This class is responsible for importing course information from
	# the source into the database.

	COURSE_DIR = "public/course"
	
	def initialize
		@errors = []
		@touched_subpages = []
	end
	
	# Re-read the course contents from the git repository.
	def run
		begin
			# get update from from git remote (pull)
			update_repo(COURSE_DIR)

			# add course info pages
			load_course_info(COURSE_DIR)
			process_info(COURSE_DIR)
			load_schedules(COURSE_DIR)
		
			# and all sections, recursively
			if Settings.submodule
				process_sections("#{COURSE_DIR}/#{Settings.submodule}")
			else
				process_sections(COURSE_DIR)
			end
				
			# remove old stuff
			prune_untouched
			prune_empty
			recreate_all_slugs
		
			# put psets in order
			CourseTools.clean_psets
		rescue SQLite3::BusyException
			@errors << "A timeout occurred while loading the new course content. Just try again!"
		end
		
		return @errors
	end

private

	def prune_untouched
		# remove any subpage that was apparently not in the repo anymore
		Subpage.where("id not in (?)", @touched_subpages).delete_all
	end
	
	def prune_empty
		# remove all pages having no subpages
		to_delete = Page.includes(:subpages).where(:subpages => { :id => nil }).pluck(:id)
		Page.where("id in (?)", to_delete).delete_all

		# remove all sections having no pages
		to_delete = Section.includes(:pages).where(:pages => { :id => nil }).pluck(:id)
		Section.where("id in (?)", to_delete).delete_all
		
		# remove psetfiles for psets that have no parent page
		# orphan_psets = Pset.includes(:page).where(:pages => { :id => nil })
		#.each do |p|
			# p.pset_files.delete_all
		# end
		
		# remove psets that have no submits and no parent page
		# to_remove = Pset.where("psets.id in (?)", orphan_psets.map(&:id)).includes(:submits).where(:submits => { :id => nil }).pluck(:id)
		# Pset.where("psets.id in (?)", to_remove).delete_all
	end
	
	def recreate_all_slugs
		Section.all.each do |p|
			p.update(slug: nil)
		end
		Page.all.each do |p|
			p.update(slug: nil)
		end
	end
	
	# Performs a git pull on the course repo. `Git.pull` has been
	# overridden in an initializer in order to function well!
	#
	def update_repo(dir)
		if !CourseGit.pull
			@errors << "Repo could not be updated from remote. You can simply try again."
		end
	end
	
	# Loads course settings from the course.yml file
	#
	def load_course_info(dir)
		if config = read_config(File.join(dir, 'course.yml'))
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

		if grading = read_config(File.join(dir, 'grading.yml'))
			Settings['grading'] = grading
		end
	end
	
	def load_schedules(dir)
		
		# load the default schedule in the root of the course folder (if available)
		if contents = read_config(File.join(dir, 'schedule.yml'))
			schedule = Schedule.where(name: 'Standard').first_or_create
			schedule.load(contents)
		end
		
		# load all schedules in the "schedules" folder (if available)
		yaml_files_in(File.join(dir, "schedules")) do |schedule_file|
			schedule_name = upcase_first_if_all_downcase(File.basename(schedule_file, ".*"))
			schedule = Schedule.where(name: schedule_name).first_or_create
			if contents = read_config(schedule_file)
				schedule.load(contents)
			end
		end
	end
	

	# Reads the `info` directory in the course repo. It creates a
	# page for it and fills it with the subpages. This special page
	# does not support forms and submitting of psets.
	#
	def process_info(dir)
		# info should be a subdir of the root course dir and contain markdown files
		info_dir = File.join(dir, 'info')
		if File.exist?(info_dir)
			info_page = Page.create(:title => Settings.long_course_name, :position => 0, :path => 'info')
			process_subpages(info_dir, info_page)
		end
	end
	
	# Reads the top-level sections from the course repo. Creates a
	# section in the database and recursively reads pages in the section.
	#
	def process_sections(dir)
		
		# sections should be direct descendants of the root course dir
		subdirs_of(dir) do |section|
			
			section_path = File.basename(section)
			next if section_path == "info" # skip info directory

			# if this directory name is parsable
			section_info = split_info(section_path)
			if section_info
				# db_sec = Section.create(:title => section_info[2], :position => section_info[1], :path => section_path)
				db_sec = Section.find_by_path(section_path) || Section.new(path: section_path)
				db_sec.title = upcase_first_if_all_downcase(section_info[2])
				db_sec.position = section_info[1]
				db_sec.save
				
				process_pages(section, db_sec)
			end
		end

	end
	
	def upcase_first_if_all_downcase(s)
		s == s.downcase && s.sub(/\S/, &:upcase) || s
	end
	
	# Reads the second-level pages from the course repo. Creates a page
	# in the database and recursively reads subpages in the page.
	#
	def process_pages(dir, parent_section)
		
		# each page is a descendant of a section and contains one or more markdown subpages
		subdirs_of(dir) do |page|
			
			page_path = File.basename(page)    # only the directory name
			page_info = split_info(page_path)  # array of position and page name

			# if this directory name is parsable
			if page_info
				# create the page
				# db_page = parent_section.pages.create(:title => page_info[2], :position => page_info[1], :path => page_path)
				
				db_page = parent_section.pages.find_by_path(page_path) || parent_section.pages.new(path: page_path)
				db_page.title = upcase_first_if_all_downcase(page_info[2])
				db_page.position = page_info[1]
				db_page.save

				# load submit.yml config file which contains items to submit
				submit_config = read_config(files(page, "submit.yml"))

				# add pset to database
				if submit_config
					
					db_pset = nil
					
					if submit_config['name']
						# checks if pset already exists under name
						db_pset = Pset.where(:name => submit_config['name']).first_or_initialize
						db_pset.description = page_info[2]
						db_pset.message = submit_config['message'] if submit_config['message']
						db_pset.form = !!submit_config['form']
						db_pset.url = !!submit_config['url']
						db_pset.page = db_page  # restore link to owning page!
						if submit_config['files']
							db_pset.files = submit_config['files']
						else
							db_pset.files = nil
						end
						db_pset.save
						
						Pset.where("id != ?", db_pset).where(page_id: db_page).update_all(page_id: nil)

						# remove previous files
						# db_pset.pset_files.delete_all

						# always recreate so it's possible to remove files from submit
						# ['required', 'optional'].each do |modus|
						# 	if submit_config[modus]
						# 		submit_config[modus].each do |file|
						# 			db_pset.pset_files.create(:filename => file, :required => modus == 'required')
						# 		end
						# 	end
						# end
					end
										
					if submit_config['dependent_grades']
						submit_config['dependent_grades'].each do |grade|
							pset = Pset.where(:name => grade).first_or_create
							pset.update_attribute(:page_id, db_page.id)
						end
					end
				else
					Pset.where(page_id: db_page).update_all(page_id: nil)
				end
				process_subpages(page, db_page)
			end
	
		end
	end

	# Reads the third-level subpages from the course repo. Creates a
	# subpage (tab) in the database for each.
	#
	def process_subpages(dir, parent_page)
		markdown_files_in(dir) do |subpage|

			subpage_path = File.basename(subpage)
			subpage_info = split_info(subpage_path)
			
			# if parsable file name
			if subpage_info
				file = IO.read(File.join(dir, subpage_path))
				# new_subpage = parent_page.subpages.create(:title => subpage_info[2], :position => subpage_info[1], :content => file)
				new_subpage = parent_page.subpages.find_by_title(subpage_info[2]) || parent_page.subpages.new(title: subpage_info[2])
				new_subpage.position = subpage_info[1]
				new_subpage.content = file
				new_subpage.save
				@touched_subpages << new_subpage.id
			end
		end

		asciidoc_files_in(dir) do |subpage|

			subpage_path = File.basename(subpage)
			subpage_info = split_info(subpage_path)
			
			# if parsable file name
			if subpage_info
				file = IO.read(File.join(dir, subpage_path))
				
				Rails.logger.info "HAAAI #{parent_page.public_url}"
				
				document = Asciidoctor.load file, safe: :safe, attributes: { 'showtitle' => true, 'imagesdir' => parent_page.public_url, 'skip-front-matter' => true }
				html = document.convert
				
				new_subpage = parent_page.subpages.find_by_title(subpage_info[2]) || parent_page.subpages.new(title: subpage_info[2])
				new_subpage.position = subpage_info[1]
				new_subpage.content = html
				new_subpage.save
				@touched_subpages << new_subpage.id
			end
		end
	end

	# Returns a subdir glob pattern.
	#
	def subdirs(*name)
		return File.join(name, "*/")
	end
	
	def subdirs_of(*name)
		Dir.glob(subdirs(name)).each do |dir|
			yield dir
		end
	end

	# Returns a file glob pattern. Yes, this is a really simple function.
	#	
	def files(*name)
		return File.join(name)
	end
	
	def files_in(*name)
		Dir.glob(files(name)).each do |file|
			yield file
		end
	end
	
	def markdown_files_in(*name)
		files_in(name, "*.md") do |file|
			yield file
		end
	end

	def asciidoc_files_in(*name)
		files_in(name, "*.adoc") do |file|
			yield file
		end
	end

	def yaml_files_in(*name)
		files_in(name, "*.yml") do |file|
			yield file
		end
	end

	# Splits a path name of the form "nn textextextext" into two parts.
	# Only accepts paths where the first characters are numbers and
	# followed by white space.
	#	
	def split_info(object)
		return object.match('(\d+)\s+(.*).md$') || object.match('(\d+)\s+(.*)$') || [object, 0, object]
	end
	
	# Reads the config file and returns the contents.
	#
	def read_config(filename)
		if File.exists?(filename)
			begin
				return YAML.load_file(filename)
			rescue
				@errors << "A yml was in an unreadable format. Did you confuse tabs and spaces?"
				return false
			end
		else
			return false
		end
	end

end
