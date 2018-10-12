require 'open3'

require 'lib/issue.rb'
require 'lib/confine/port-shutdown'
require 'lib/confine/acl-mac-core'

module Confine
#
path = File.expand_path(File.dirname(__FILE__))
PATH = File.join(path, '/../../../switch/bin/')
#
if defined?(CONFINEMENT_DRY_RUN)
	OPTION = ' -d'
else
	OPTION = ''
end

def self.confine(id, locate, type)
	begin
		output, result = Confine.send(type, id, locate)
	rescue => e
		result = false
		output = '' if ! output
		output += "FAILED: #{e.to_s}\n"
	end
	return result, output
end

end
