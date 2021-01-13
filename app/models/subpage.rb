class Subpage < ActiveRecord::Base

	# this generates a url friendly part for the subpage (used for html ids in this case)
	extend FriendlyId
	friendly_id :title, :use => :slugged

	belongs_to :page

	default_scope { order(:position) }

	def self.load(filename, contents, parent)
		if subpage_info = split_info(filename)
			new_subpage = parent.subpages.find_by_title(subpage_info[2]) || parent.subpages.new(title: subpage_info[2])
			new_subpage.position = subpage_info[1]
			new_subpage.content = contents
			new_subpage.save
			return new_subpage.id
		end
	end

	def self.split_info(object)
		return object.match('(\d+)\s+(.*).md$') || object.match('(\d+)\s+(.*)$') || [object, 0, object]
	end

end
