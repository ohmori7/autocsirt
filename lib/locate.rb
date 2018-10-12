require 'lib/locate/wired'
require 'lib/locate/wireless'
require 'lib/locate/ondemand'

module Locate

path = File.expand_path(File.dirname(__FILE__))
PATH = File.join(path, '/../../netutils/bin/')

class Locate
	attr_reader :ia, :time, :ma, :nas, :nasia, :nasport, :starttime,
	    :userid, :corename, :coreia, :output

	def initialize(name, addr, time)
		@addr = addr
		case addr
		when /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/
			@ia = addr
		when /^[0-9a-z:.\-]+$/i
			@ma = addr
		else
			raise("Invalid address format: #{addr}")
		end
		@time = time
		extend Kernel.const_get('Locate').const_get(name)
	end

	def located?
		@located
	end

	def locate
		ooutput = @output
		ooutput = '' if ! ooutput
		begin
			_locate
			@located = true
		rescue => e
			ooutput += <<~EOF
			ERROR: cannot locate #{@ia} for ``#{name}'': #{e.to_s}
			ERROR: fall back to on-demand locating
			EOF
			extend ::Locate::OnDemand
			begin
				_locate
				@located = true
			rescue => e
				ooutput += e.to_s
			end
		end
		@output = "#{ooutput}#{@output}"
		@output += to_s
	end

	def to_s
		<<~EOF
		Latest seen time: #{@starttime}
		     Access time: #{@time}
		      IP address: #{@ia}
		     MAC address: #{@ma}
		             NAS: #{@nas} (#{@nasia})
		            Port: #{@nasport}
		         User ID: #{@userid}
		          source: #{name}
		EOF
	end
end

end
