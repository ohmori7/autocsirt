require 'mail'

class TemplateMailer
	HEADERS = [ :to, :from, :cc, :subject ]
	NONE = '-'

	def initialize(smtpserver, template, options)
		@smtpserver = smtpserver
		@options = options.dup
		_load_template(template)
		@attachments = []
	end

	def attach(filename)
		@attachments << filename
	end

	def mail(to = nil, cc = nil)
		m = Mail.new
		m.delivery_method(:smtp, address: @smtpserver)
		m.from = @options[:from]
		if to
			m.to = to
		elsif @options[:to]
			m.to = @options[:to]
		end
		if cc
			cc = [ cc ] if ! cc.is_a?(Array)
		else
			cc = [ @options[:from] ]
			cc << @options[:cc] if @options[:cc]
		end
		m.cc = cc.uniq.join(', ')
		m.subject = @options[:subject]
		if @attachments.empty?
			# do not use multipart without attachments.
			m.charset = 'utf-8'
			m.body = @options[:body]
		else
			m.text_part = Mail::Part.new(body: @options[:body],
			    content_type: 'text/plain; charset=UTF-8')
			@attachments.each do |path|
				m.attachments[File.basename(path)] =
				    File.binread(path)
			end
		end
		m.deliver!
		_extract_sent_mail(m)
	end

	private

	def _load_template(file)
		file = File.dirname(__FILE__) + '/../config/' + file
		file = File.expand_path(file)

		msg = File.read(file)
		@options.each do |key, value|
			msg.gsub!("%%#{key.to_s.upcase}%%", value.to_s)
		end
		msg.gsub!(/%%[^%]+%%/, NONE)

		@options[:body] = ''
		header = true
		msg.each_line do |l|
			if header && l =~ /^[^\s]+: /
				HEADERS.each do |h|
					if l =~ /^#{h}:\s+(.*)$/i
						@options[h.downcase.to_sym] = $1
						break
					end
				end
				next
			else
				header = false
			end
			@options[:body] += l
		end
	end

	def _extract_sent_mail(m)
		names = [ 'From', 'To', 'Cc', 'Subject', 'Date', 'Message-ID' ]
		mail = ''
		names.each do |name|
			m.header.fields.each do |header|
				next if header.name != name
				mail += "#{name}: #{header.value}\n"
				break
			end
		end
		mail += "\n"
		mail += m.body.raw_source
		mail
	end
end
