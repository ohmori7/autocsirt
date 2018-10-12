require 'lib/iprange'
require 'lib/iptype'
require 'lib/contact'

class IPTable
	class IP < IPRange
		attr_reader :media, :type, :contact, :division,
		    :section, :remark

		def initialize(range, media, type, contact, division,
		    section, remark)
			super(range)
			@media = media
			@type = type
			@contact = contact
			@division = division
			@remark = remark
		end
	end

	def initialize
		# load all contacts here every time so that file contents may change.
		@contacts = Contacts.new(CONTACT)
		@iptypes = IPTypes.new(IPADDRESSTYPE)
		@ranges = []
		load(IPADDRESS)
	end

	def lookup(ia)
		m = nil
		@ranges.each do |r|
			if r.include?(ia)
				if ! m || m < r
					m = r
				end
			end
		end
		m
	end

	private

	def exists?(other)
		@ranges.each do |r|
			return true if r == other
		end
		false
	end

	def file_path(file)
		File.expand_path(File.dirname(__FILE__) + '/../db/' + file)
	end

	def load(file)
		CSV.foreach(file_path(file), headers: true) do |row|
			r = IP.new(row['range'], row['media'],
			    @iptypes[row['type'], row['media']],
			    @contacts[row['contact']],
			    row['division'], row['section'], row['remark'])
			raise "Duplicate IP address range: #{r}" if exists?(r)
			@ranges <<= r
		end
	end
end

# XXX
if $0 == __FILE__
	iptable = IPTable.new(ARGV[0], ARGV[1], ARGV[2])
	m = iptable.lookup(ARGV[2])
	puts ARGV[2]
	if m
		puts m.to_s
		puts m.media
		puts m.type
		puts m.contact
		puts m.division
		puts m.remark
	end
end
