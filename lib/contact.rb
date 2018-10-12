require 'csv'

class Contacts
	class Contact
		attr_reader :name, :mailaddrs

		def initialize(name, mailaddrs)
			@name = name
			@mailaddrs = mailaddrs.compact
		end

		def to_s
			@name
		end
	end

	def initialize(file)
		@contacts = {}
		load(file)
	end

	def [](name)
		@contacts[name]
	end

	private

	def load(file)
		file = File.dirname(__FILE__) + '/../db/' + file
		file = File.expand_path(file)
		CSV.foreach(file, headers: true) do |row|
			i = 0
			mailaddrs = []
			while mailaddr = row[i] do
				mailaddrs << mailaddr
				i += 1
			end
			name = mailaddrs.shift
			if @contacts.has_key?(name)
				raise "ERROR: Already exists: #{name}"
			end
			@contacts[name] = Contact.new(name, mailaddrs)
		end
	end
end

# XXX
if $0 == __FILE__
	c = Contacts.new
	c.load(ARGV[0])
	p c
end
