require 'lib/mongo'

module Locate

module Wireless
	include SOC::Mongo

	def name
		'Wireless RADIUS accounting using MongoDB'
	end

	def _locate
		acct_wireless
	end
end

end
