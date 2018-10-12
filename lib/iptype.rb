class IPTypes
	class IPType
		attr_reader :name, :locate, :confine

		def initialize(name, media, locate, confine)
			@name = name
			@media = media
			@locate = locate
			@confine = confine
		end
	end

	def initialize(ipaddresstypefile)
		@types = {}
		load(ipaddresstypefile)
	end

	def [](type, media)
		return nil if ! @types.has_key?(type)
		@types[type][media]
	end

	private

	def file_path(file)
		File.expand_path(File.dirname(__FILE__) + '/../db/' + file)
	end

	def load(file)
		CSV.foreach(file_path(file), headers: true) do |row|
			type = row['type']
			media = row['media']
			@types[type] = {} if ! @types.has_key?(type)
			if @types[type].has_key?(media)
				raise "Duplicate IP address type: #{type}" +
				    " and #{media}"
			end
			@types[type][media] = IPType.new(type,
			    media, row['locate'], row['confine'])
		end
	end
end
