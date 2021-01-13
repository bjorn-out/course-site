class Page < ActiveRecord::Base

	# this generates a url friendly part for the page
	extend FriendlyId
	friendly_id :title, use: [ :slugged, :scoped ], scope: :section

	belongs_to :section  # parent section
	has_many :subpages   # content tabs
	has_one :pset        # linked pset if available

	# Make sure the subpages are always ordered
	default_scope { order(:position) }
	
	def public_url
		the_path = ["/course"]
		the_path << Settings.submodule if Settings.submodule
		the_path << section.path if section
		the_path << path
		
		return File.join(the_path)
		# if section
		# 	return File.join('/course', section.path, path)
		# else
		# 	return File.join('/course', path)
		# end
	end
	
	def self.load(path, parent)
		# if this directory name is parsable
		if page_info = split_info(path)
			db_page = parent.pages.find_by_path(path) || parent.pages.new(path: path)
			db_page.title = upcase_first_if_all_downcase(page_info[2])
			db_page.position = page_info[1]
			db_page.save
			return db_page
			# load submit.yml config file which contains items to submit
			# submit_config = read_config(files(page, "submit.yml"))

			# add pset to database
			# if submit_config
			#
			# 	db_pset = nil
			#
			# 	if submit_config['name']
			# 		# checks if pset already exists under name
			# 		db_pset = Pset.where(:name => submit_config['name']).first_or_initialize
			# 		db_pset.description = page_info[2]
			# 		db_pset.message = submit_config['message'] if submit_config['message']
			# 		db_pset.form = !!submit_config['form']
			# 		db_pset.url = !!submit_config['url']
			# 		db_pset.page = db_page  # restore link to owning page!
			# 		if submit_config['files']
			# 			db_pset.files = submit_config['files']
			# 		else
			# 			db_pset.files = nil
			# 		end
			# 		db_pset.save
			#
			# 		Pset.where("id != ?", db_pset).where(page_id: db_page).update_all(page_id: nil)
			#
			# 		# remove previous files
			# 		# db_pset.pset_files.delete_all
			#
			# 		# always recreate so it's possible to remove files from submit
			# 		# ['required', 'optional'].each do |modus|
			# 		# 	if submit_config[modus]
			# 		# 		submit_config[modus].each do |file|
			# 		# 			db_pset.pset_files.create(:filename => file, :required => modus == 'required')
			# 		# 		end
			# 		# 	end
			# 		# end
			# 	end
			#
			# 	if submit_config['dependent_grades']
			# 		submit_config['dependent_grades'].each do |grade|
			# 			pset = Pset.where(:name => grade).first_or_create
			# 			pset.update_attribute(:page_id, db_page.id)
			# 		end
			# 	end
			# else
			# 	Pset.where(page_id: db_page).update_all(page_id: nil)
			# end
			# process_subpages(page, db_page)
		end
		return nil
	end
	
	# Splits a path name of the form "nn textextextext" into two parts.
	# Only accepts paths where the first characters are numbers and
	# followed by white space.
	#	
	def self.split_info(object)
		return object.match('(\d+)\s+(.*).md$') || object.match('(\d+)\s+(.*)$') || [object, 0, object]
	end

	def self.upcase_first_if_all_downcase(s)
		s == s.downcase && s.sub(/\S/, &:upcase) || s
	end

end
