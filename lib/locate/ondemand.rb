require 'open3'

module Locate

module OnDemand
	def name
		'On-Demand ARP+MAC+LLDP'
	end

	def __locate(direct_only = false)
		option = ' -d' if direct_only
		@output, @error, @status =
		    Open3.capture3("#{PATH}/host-locate-on-demand" +
		    "#{option} #{@ia}")

		if @output !~ /\Alocating dir[^\n]+\n\s+\"([^"]+)" \(([^\)]+)\)/
			raise "cannot locate a core switch"
		end
		@corename = $1
		@coreia = $2
		return if direct_only

		if @output !~ /^\s+#{@ia.gsub('.', '\.')}\s+([^\s]+)\s+/mi
			raise "cannot resolve a MAC address for #{@ia}"
		end
		@ma = $1

		if @output !~ /^\s+([^\n\s]+) \(([^\)]+)\)\s+([^\n]+)\Z/m
			raise "cannot locate an edge switch and port"
		end
		@nas = $1
		@nasia = $2
		@nasport = $3

		@starttime = Time.now
	end

	def _locate
		__locate
	end

	def locate_directly_connected_router
		__locate(true)
	end
end

end
