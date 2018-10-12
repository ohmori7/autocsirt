# coding:utf-8

require 'lib/redmine/api.rb'

class Issue
	KEYS = {
		id:			'#',
		status:			'ステータス',
		subject:		'題名',
		created_on:		'作成日',
		# custom fields.
		detection:		'検知',			# mandatory
		threat:			'脅威',			# mandatory
		malware:		'マルウェア名',
		malwaretype:		'マルウェアの種類',
		confinement:		'通信遮断',
		isolation:		'端末隔離',
		corresponding_ia:	'通信先学外IPアドレス',
		ia:			'プライベートIPアドレス',
		ma:			'MACアドレス',
		global_ia:		'グローバルIPアドレス',
		network:		'ネットワーク区分',
		media:			'LAN区分',
		starttime:		'発生日時',
		endtime:		'終了日時',
		department:		'部局',
		division:		'学科・専攻/課・係',
		usertype:		'利用者区分',
		userid:			'利用者鳥大ID',
		confidential:		'個人情報',
		plain:			'平文の個人情報',
		breach:			'情報漏洩',
		socticketid:		'SOCチケット番号',
		socincidentid:		'SOCインシデントID',
		socticketstatus:	'SOCチケットステータス',
		socdate:		'SOC通知日時',
		abstract:		'概要',
	}

	module Values
		STATUS = {
			detected:	'認知(センター)',
			identifying:	'端末特定・調査待ち(部局)',
			investigating:	'端末情報漏洩調査中(センター)',
			investigated:	'端末情報漏洩調査完了(センター)',
			finalreport:	'最終報告待ち(部局)',
			reinstall:	'OS再インストール待ち(学生)',
			falsepositive:	'誤検知(対応完了)',
			confirmation:	'確認作業(対応完了)',
			duplicated:	'他チケットと同一端末(対応完了)',
			outofscope:	'担当業務外(対応完了)',
			noncritical:	'非重大インシデント(対応完了)',
			done:		'終了(対応完了)',
		}

		THREAT = {
			malware:	'マルウェア'
		}

		CONFINEMENT = {
			none:		'未実施',
			firewall:	'ファイアウォール(IPアドレス)',
			port_shutdown:	'エッジスイッチ(ポートシャットダウン)',
			acl_ip_core:	'コアスイッチ(MACアドレス)',
			acl_mac_core:	'コアスイッチ(MACアドレス)',
			wlan:		'無線LAN認証(MACアドレス)',
		}

		ISOLATION = {
			identifying:	'端末特定中',
			isolated:	'隔離済み',
			restored:	'隔離解除',
			none:		'未実施',
		}

		CONFIDENTIAL = {
			yes:		'有',
			no:		'無',
		}

		USERTYPE = {
			staff:		'教職員',
			student:	'学生',
			other:		'その他',
		}
	end

	def initialize(api = nil)
		api = Redmine::API.new if ! api
		@api = api
		@fields = {}
		@fields['custom_fields'] = []
	end

	def create(options)
		# make these values mandatory
		self['subject'] = options[:subject]
		self['description'] = options[:description]
		#
		self['watcher_user_ids'] =
		    @api.get_group_users(REDMINE_WATCHER_GROUP)
		#
		options[:threat] = Values::THREAT[:malware]
		if options.has_key?(:malware) && ! options[:malware].empty?
			options[:malware] = options[:malware]
		end
		_set_default_value(options, :confinement,
		    Values::CONFINEMENT[:none])
		KEYS.each do |key, redminekey|
			next if ! options.has_key?(key)
			self[key] = options[key]
		end
		@fields = @api.create_issue(@fields)['issue']
	end

	def set(values)
		values.each do |key, value|
			@fields[key] = value
		end
	end

	def []=(key, value)
		value = value.strftime('%Y/%m/%d %T') if value.is_a?(Time)

		case key.to_sym
		when :status
			@fields['status_id'] = @api.get_status_id(value)
		when :id, :project, :tracker, :subject, :description,
		    :watcher_user_ids
			@fields[key] = value
		else
			rkey = KEYS[key]
			id, value = @api.get_custom_field_value(rkey, value)
			@fields['custom_fields'] << { id: id, value: value }
		end
	end

	def [](key)
		case key.to_sym
		when :id, :subject, :description, :created_on, :updated_on
			return @fields[key.to_s]
		when :project, :tracker, :status, :watcher_user_ids
			return @fields[key.to_s]['name']
		else
			@fields['custom_fields'].each do |field|
				name = @api.custom_field_name(Issue::KEYS[key])
				next if field['name'] != name
				return @api.get_custom_field_value_label(
				    Issue::KEYS[key], field['value'])
			end
		end
		nil
	end

	def id
		self['id']
	end

	def incident?
		excludes = [
		    :falsepositive, :confirmation, :duplicated, :outofscope,
		    :noncritical ]
		excludes = excludes.map { |key| Values::STATUS[key] }
		! excludes.include?(self[:status])
	end

	def done?
		done = [ :falsepositive, :confirmation, :duplicated,
		    :outofscope, :noncritical, :done ]
		done.map { |key| Values::STATUS[key] }.include?(self[:status])
	end

	def <=>(other)
		self.id <=> other.id
	end

	def update(notes = nil)
		@fields['notes'] = notes if notes
		@api.update_issue(@fields)
		@fields.delete('notes')
	end

	private

	def _set_default_value(options, key, value)
		return if options.has_key?(key)
		options[key] = value
	end
end
