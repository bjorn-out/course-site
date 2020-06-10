class AskMailer < ApplicationMailer

	def ask_me_anything(user, question, ip)
		mail(
		to: Settings.mailer_from,
		from: user.mail,
		body: question + "\n\n" + "(Sent from #{ip})",
		content_type: "text/plain",
		subject: "Question about #{Course.short_name}")
	end

end
