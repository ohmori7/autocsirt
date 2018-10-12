require 'lib/templatemailer'

class Alert < TemplateMailer
	def initialize(options)
		super(ALERT_SMTP_SERVER, ALERT_TEMPLATE, options)
	end

	def mail
		to = ALERT_TO if defined?(ALERT_TO)
		cc = ALERT_CC if defined?(ALERT_CC)
		super(to, cc)
	end
end
