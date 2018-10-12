# -*- encoding: utf-8 -*-

require 'lib/soc/nii/niisocs'

module SOC

class NII < SOC

	def initialize(mailaddr)
		super('NII-SOCS', mailaddr)
	end

	def ljust(s, width, pad = ' ')
		len = s.chars.map{ |c| c.bytesize === 1 ? 1 : 2 }.inject(0, &:+)
		padlen = [ 0, width - len ].max
		s + pad * padlen
	end

	def parse(options, mailsubject, body)
		if mailsubject !~ /^\s*セキュリティ運用連携サービス 要確認情報のお知らせ(.*)?$/
			raise "ERROR: invalid subject format: #{subject}"
		end

		# session information does not have ID.
		subject = nil
		if ! $1.nil? && $1 =~ /_警報ID：([0-9]+)$/
			alarmid = $1
			body.each_line do |l|
				if l =~ /^警報ID:[0-9]+  capture_time:([^,]+), inside_ip:([^,]+), alarm_name:(.*)$/
					options[:time] = Time.parse($1)
					options[:global_ia] = $2
					subject = $3
					break
				end
			end

			socs = NIISOCS.new
			keys, values = socs.alarm_get(alarmid)

			options[:socticketid] = values['チケット番号']
			options[:socincidentid] = alarmid

			case options[:global_ia]
			when values['攻撃元IP']
				options[:sport] = values['攻撃元ポート']
				options[:dport] = values['攻撃先ポート']
				options[:corresponding_ia] = values['攻撃先IP']
			when values['攻撃先IP']
				options[:sport] = values['攻撃先ポート']
				options[:dport] = values['攻撃元ポート']
				options[:corresponding_ia] = values['攻撃元IP']
			end

			options[:description] += "\n```\n"
			options[:description] += "#{values['title']}\n"
			keys.each do |key|
				options[:description] += sprintf("%s %s\n",
				    ljust(key, 24), values[key])
			end
			options[:description]  += "```\n"
		end

		if subject.nil?
			subject = "マルウェア感染疑い"
		end
		options[:subject] = options[:debug].to_s + subject

		if defined?(NII_SOCS_CONFINEMENT) && ! NII_SOCS_CONFINEMENT
			options[:confinement] =
			    Issue::Values::CONFINEMENT[:none]
		end

		true
	end
end

end
