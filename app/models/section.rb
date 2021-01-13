class Section < ActiveRecord::Base

	# this generates a url friendly part for the section
	extend FriendlyId
	friendly_id :title, :use => :slugged

	has_many :pages

	# Make sure the subpages are always ordered
	default_scope { order(:position) }
	
	def normalize_friendly_id(string)
		super.gsub("problem-sets", "psets")
	end
	
	def self.load(pathname)
		# if this directory name is parsable
		if section_info = split_info(pathname)
			db_sec = find_by_path(pathname) || new(path: pathname)
			db_sec.title = upcase_first_if_all_downcase(section_info[2])
			db_sec.position = section_info[1]
			db_sec.save
			return db_sec
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
