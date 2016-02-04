#
#  Get remote git data, either by pulling existing, or cloning anew.
#
module CourseGit

	def self.pull
		if git = self.existing_local_repo
			begin
				git.pull 'origin', git.current_branch
			rescue Git::GitExecuteError
				return false
			end
		else
			if Settings.git_repo.present?
				git = Git.clone(Settings.git_repo, 'public/course', branch:self.get_remote_branch, depth:1, log:Rails.logger)
			end
		end
		
		return true
	end
	
	def self.existing_local_repo
		return Git.open('public/course', log:Rails.logger)
	rescue
		return nil
	end
	
	def self.get_remote_branch
		remote_branch = Settings.git_branch
		remote_branch = 'master' if remote_branch.blank?
		return remote_branch
	end

end
