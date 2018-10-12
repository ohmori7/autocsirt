module SOC

class SOC
	attr_reader :name, :mailaddr

	def initialize(name, mailaddr)
		@name = name
		@mailaddr = mailaddr
	end
end

end
