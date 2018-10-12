require 'open3'

module Confine

def self.port_shutdown(id, locate)
	if ! locate || ! locate.nasia || ! locate.nasport
		raise('insufficient information given')
	end

	cmd = "#{PATH}/port-shutdown#{OPTION} down " +
	    "#{locate.nasia} \'#{locate.nasport}\'"
	output, error, status = Open3.capture3(cmd)
	return output + error, status.exitstatus === 0 ? true : false
end

end
