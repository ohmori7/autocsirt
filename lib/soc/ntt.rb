# -*- encoding: utf-8 -*-

require 'lib/iprange'

module SOC

class NTT < SOC
	KEYWORDS = {
		ia:		'被害対象',
		time:		'発生時刻',
		malware:	'攻撃情報',
		leakage:	'情報漏洩の証跡',
		target:		'標的型攻撃の証跡',
		remarks:	'備考',
		timelog:	'Date',
		srcia:		'Src IP',
		dstia:		'Dst IP',
	}
	MANDATORY = [
		:ia, :time
	]

	def initialize(mailaddr)
		super('WideAngle', mailaddr)
	end

	def date_parse(s)
		begin
			Time.parse(s)
		rescue
		end
	end
	private :date_parse

	def victim_ia(srcia, dstia)
		INTERNAL_IP_ADDRESSES.each do |s|
			if IPRange.new(s).include?(srcia)
				return srcia, dstia
			end
		end
		return dstia, srcia
	end
	private :victim_ia

	def parse(options, subject, body)
		return false if subject !~ /Analysis Report/

		if subject !~ /^.*[<\[]([0-9]+)[>\]]\s*Analysis Report\s*[<\[]([^>\]]+)[>\]]\s*(?:Critical|Serious)_(.*)$/
			raise "ERROR: invalid subject format: #{subject}"
		end

		options[:socticketid] = $1

		status = $2.downcase
		status = 'open' if status === 'update'
		options[:socticketstatus] = status

		options[:subject] = options[:debug].to_s + $3.strip

		is_ia = false
		body.each_line do |l|
			if is_ia
				if l =~ /^[0-9.\[\]]+\s*$/
					if ! options.has_key?(:ia)
						options[:ia] = []
					elsif ! options[:ia].is_a?(Array)
						options[:ia] = [ options[:ia] ]
					end
					v = l.strip.delete('[]')
					options[:ia] << v
					next
				else
					is_ia = false
				end
			end
			KEYWORDS.each do |id, keyword|
				next if options.has_key?(id)
				next if l !~ /^#{keyword}:(.*)$/
				v = $1.strip
				if id === :ia
					v.delete!('[]')
					is_ia = true
				end
				#
				case v
				when 'ー', '―', '×', ''
					next
				end
				options[id] = v
				break
			end
		end
		if options.has_key?(:timelog) && ! options.has_key?(:time)
			options[:time] = options[:timelog]
			options.delete(:timelog)
		end
		if options.has_key?(:dstia)
			dstia = options[:dstia].delete('[]')
			srcia = options[:srcia].delete('[]')
			ia, options[:corresponding_ia] = victim_ia(srcia, dstia)
			options[:ia] = ia if ! options.has_key?(:ia)
		end

		keys = [ :socticketid, :subject ].concat(MANDATORY)
		notfound = keys.reject { |key| options.has_key?(key) }
		if ! notfound.empty?
			raise 'ERROR: cannot parse message due to ' +
			    "missing field: #{notfound}"
		end

		s, e = options[:time].split(/[〜-]/).map { |t| t.strip }
		options[:starttime] = date_parse(s)
		options[:endtime] = date_parse(e)

		true
	end
end

end
