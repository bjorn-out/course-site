class CourseTools
	
	#
	#
	# Walks all psets named in course.yml and ranks them in the database
	
	def CourseTools.clean_psets

		# an Array only contains pset names and order
		if Settings['psets'].class == Array
			counter = 1
			Settings['psets'].each do |pset|
				if p = Pset.find_by(name:pset)
					p.update_attribute(:order,counter)
					counter += 1
				end
			end

		# a Hash contains pset names, order and weight!
		elsif Settings['psets'].class == Hash
			counter = 1
			Settings['psets'].each do |pset, weight|
				if p = Pset.find_by(name:pset)
					p.update_attributes(order: counter, weight: weight)
					counter += 1
				end
			end
		end
		
		if Settings['grading'] && Settings['grading']['grades']
			counter = 1
			Settings['grading']['grades'].each do |name, definition|
				p = Pset.where(name: name).first_or_create
				p.update_attribute(:order, counter)
				p.update_attribute(:grade_type, definition['type'] || :float)
				counter += 1
			end
			# p = Pset.where(name: 'final').first_or_create
			# p.update_attribute(:order, counter)
			# p.update_attribute(:grade_type, :float)
			Settings['grading']['calculation'].each do |name, formula|
				p = Pset.where(name: name).first_or_create
				p.update_attribute(:order, counter)
				p.update_attribute(:grade_type, :float)
			end			
		end

	end
	
	def prune_untouched(touched_subpages)
		# remove any subpage that was apparently not in the repo anymore
		Subpage.where("id not in (?)").delete_all
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

	
end
