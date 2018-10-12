require 'open3'
require 'lib/locate' # XXX

module Confine

def self.acl_mac_core(id, locate)
	if ! locate || ! locate.ma
		raise('insufficient information given')
	end

	#
	# a core switch may not be resolved here because a host may be located
	# by RADIUS accounting.  therefore, locate a core switch.
	# XXX: should be in other palce???
	#
	coreia = locate.coreia
	corename = locate.corename
	oooutput = ''
	if ! coreia
		l = ::Locate::Locate.new('OnDemand', locate.ia, nil)
		l.locate_directly_connected_router
		coreia = l.coreia
		corename = l.corename
		ooutput = l.output if l.output
	end

	# allow to define an ACL type per switch basis.
	special = 'CONFINEMENT_ACL_TYPE_' + corename.gsub('-', '_')
	if Module.const_defined?(special)
		type = Module.const_get(special)
	else
		type = CONFINEMENT_ACL_TYPE
	end

	name = CONFINEMENT_ACL_NAME

	cmd = "#{PATH}/acl#{OPTION} add #{coreia} #{type} #{name} " +
	    "#{id} #{locate.ma}"
	output, error, status = Open3.capture3(cmd)
	output = "#{ooutput}#{output}"
	return output + error, status.exitstatus === 0 ? true : false
end

end
