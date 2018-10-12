require 'ipaddr'

class IPRange
	include Comparable

	attr_reader :range

	def initialize(range)
		#
		# I know IPAddr can be used as a value of range, but
		# its comparison relatively slow.  I do not know the
		# reason why.  Anyway, we here use an integer value.
		#
		# comparison with IPAddr range:
		#    time iptable.rb a.csv b.csv 10.15.5.150
		#    1.646u 0.000s 0:01.64 100.0%    0+0k 0+0io 0pf+0w
		# comparison with integer range:
		#    time iptable.rb a.csv b.csv 10.15.5.150
		#    0.030u 0.000s 0:00.02 150.0%    0+0k 0+0io 0pf+0w
		#
		if range.include?('/')
			r = IPAddr.new(range).to_range
			first = r.first.to_i
			last = r.last.to_i
		elsif range.include?('-')
			m = range.split('-')
			first = IPAddr.new(m[0]).to_i
			last = IPAddr.new(m[1]).to_i
		else
			first = last = IPAddr.new(range).to_i
		end
		@string = range
		@range = Range.new(first, last)
	end

	def include?(ia)
		# i know this is not efficient but performance is not so bad.
		ia = IPAddr.new(ia) if ! ia.instance_of?(IPAddr)
		@range.include?(ia.to_i)
	end

	def size
		@range.last - @range.first
	end

	def <=>(other)
		diff = @range.first - other.range.first
		return diff if diff != 0
		diff = size <=> other.size
	end

	def to_s
		"#{@string.to_s}"
	end
end
