require 'lib/mongo'

module Locate

module Wired
	include SOC::Mongo

	def name
		'Wired RADIUS accounting using MongoDB'
	end


	def _locate
		acct_wired
	end
end

end
