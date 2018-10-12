# -*- encoding: utf-8 -*-

require 'net/imap'
require 'base64'
require 'date'

class IMAP < Net::IMAP
	RECONNECT_INTERVAL = 60

	def initialize(host, username, password, criteria, ssl = true)
		@username = username
		@password = password
		@criteria = criteria
		@lastuid  = 1
		port = ssl ? 993 : 143
		super(host, port, ssl)
	end

	def utf8(s, source_encoding)
		s.encode!('utf-8', source_encoding,
		    :invalid => :replace, :undef => :replace,
		    :universal_newline => true)
		s.force_encoding('utf-8')
	end
	private :utf8

	def date_decode(s)
		s = $1 if s =~ /^Date:\s+(.*)$/i
		Time.parse(s)
	end
	private :date_decode

	def mime_subject_decode(s)
		subject = ''
		s.each_line do |l|
			case l
			when /^Subject:\s+(.*)$/
				l = $1
			end
			l.strip!
			if l =~ /^=\?([a-z0-9\-]+)\?(B|Q)\?([!->@-~]+)\?=$/i
				case $2
				when 'B'
					l = Base64.decode64($3)
				when 'Q'
					l = $3.unpack('M').first.gsub('_', ' ')
				else
					raise "ERROR: unknown encode: #{$2}"
				end
				l = utf8(l, $1)
			end
			subject += l
		end
		subject
	end
	private :mime_subject_decode

	def uid_update(uid)
		return @lastuid if uid < @lastuid
		lastuid = @lastuid
		@lastuid = uid + 1
		lastuid
	end

	def uid_criteria(uid)
		[ 'uid', "#{uid}:*" ]
	end
	private :uid_criteria

	def select
		super('INBOX')
		#
		# always obtain the last uid in order not to duplicatedly
		# search the same mails next time.
		#
		uid_update(uid_search(uid_criteria(@lastuid)).last)
	end
	private :select

	def header_key(name)
		"BODY[HEADER.FIELDS (#{name.upcase})]"
	end
	private :header_key

	def uid_fetch(uid)
		headers = [
		    'return-path',
		    'received',
		    'from',
		    'to',
		    'cc',
		    'subject',
		    'date',
		    'message-id',
		    'reply-to',
		    ]
		attrs = headers.map { |h| header_key(h) }
		attrs.unshift('BODY')
		attrs.push('BODY[1]')
		data = super(uid, attrs).first

		message = {}
		message['uid'] = uid
		headers.each do |h|
			value = data.attr[header_key(h)]
			next if ! value or value.strip!.empty?
			message[h] = value
		end
		message['date'] = date_decode(message['date'])
		message['subject'] = mime_subject_decode(message['subject'])
		if data.attr['BODY'].param
			charset = data.attr['BODY'].param['CHARSET']
		end
		charset = 'iso-8859-1' if ! charset
		body = data.attr['BODY[1]']
		if data.attr['BODY'].encoding =~ /BASE64/i
			body = Base64.decode64(body)
		end
		message['body'] = utf8(body, charset)
		return message
	end
	private :uid_fetch

	def fetch
		lastuid = select
		uid_search(@criteria + uid_criteria(lastuid)).each do |uid|
			begin
				yield uid_fetch(uid)
			rescue => e
				puts "WARNING: UID: #{uid}: #{e}"
				# revert to unseen.
				unseen(uid)
			end

			# we may receive new mails after ``select''
			uid_update(uid)
		end
	end
	private :fetch

	def wait
		idle do |response|
			if response.kind_of?(Net::IMAP::UntaggedResponse) &&
			   response.name == 'EXISTS'
				# okay, we got something, break this block.
				idle_done
			end
		end
	end
	private :wait

	def unseen(uid)
		uid_store(uid, '-FLAGS', :Seen)
	end
	private :unseen

	def gets(&block)
		loop do
			begin
				login(@username, @password)
				loop do
					fetch(&block)
					wait
				end
			rescue => e
				puts "WARNING: #{e}"
			ensure
				begin
					exit
				rescue
					# ignore erros on closed connection
				end
			end
			puts "wait for #{RECONNECT_INTERVAL} seconds"
			sleep(RECONNECT_INTERVAL)
		end
	end

	def exit
		logout
		disconnect
	end
end
