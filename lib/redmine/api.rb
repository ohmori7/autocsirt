module Redmine

require 'config/config'

require 'uri'
require 'json'
require 'net/http'
require 'openssl'

class API
	def initialize
		@uri = REDMINE_URL
		@apikey = REDMINE_APIKEY
		@project = _get_project(REDMINE_PROJECT)
		@statuses = _get_statuses
		@custom_fields = _get_custom_fields
	end

	def custom_field_name(name)
		if defined?(REDMINE_KEY_PREFIX)
			name = REDMINE_KEY_PREFIX + name
		end
		name
	end

	def get_custom_field_value(name, value)
		_get_custom_field_value(name, value, [ 'label', 'value' ])
	end

	def get_custom_field_value_label(name, ivalue)
		return nil if ivalue === nil || ivalue.empty?
		id, label = _get_custom_field_value(name, ivalue,
		    [ 'value', 'label' ])
		return label
	end

	def get_custom_field_possible_values(name)
		name = custom_field_name(name)
		field = @custom_fields[name]
		raise(ArgumentError, "Unknown field: #{name}") if ! field
		if ! field.has_key?('possible_values')
			raise(ArgumentError, "Not possible values: #{name}")
		end
		return field['possible_values']
	end

	def get_status_id(name)
		if ! @statuses.has_key?(name)
			raise(ArgumentError, "No such status: #{name}")
		end
		@statuses[name]['id']
	end

	def get_group_users(name)
		_get_group(name)['users'].map { |u| u['id'] }
	end

	def get_issue(id)
		_get("issues/#{id}")
	end

	def get_issues(conditions = '')
		conditions = "?project_id=#{@project['id']}&#{conditions}"
		_get('issues', conditions)
	end

	def create_issue(issue)
		issue['project_id'] = @project['id']
		_get('issues', nil, { 'issue' => issue }, :Post)
	end

	def update_issue(issue)
		_get("issues/#{issue['id']}", nil, { 'issue' => issue }, :Put)
	end

	private

	def _cmd(path, data = nil, method = :Get)
		uri = URI.parse("#{@uri}/#{path}")

		cls = Kernel.const_get('Net').const_get('HTTP')
		cls = cls.const_get(method)
		request = cls.new(uri.request_uri)
		request.body = data.to_json if data
		request['Content-Type'] = 'application/json'
		request['X-Redmine-API-Key'] = @apikey
		#
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = @uri =~ /^https/
		http.verify_mode = OpenSSL::SSL::VERIFY_NONE # XXX

		#
		response = http.request(request)
		case response.code
		when '200', '201'
		else
			# XXX: error handling
			# XXX: redirect handling
			raise("Error has occured with Redmine: " +
			    "HTTP code: #{response.code}")
		end
		JSON.load(response.body)
	end

	def _get(key, param = nil, *arg)
		_cmd("#{key}.json#{param}", *arg)
	end

	def _get_project(identifier)
		_get('projects')['projects'].each do |project|
			return project if project['identifier'] === identifier
		end
		raise(ArgumentError, "No such project: #{identifier}")
	end

	def _get_statuses
		hash = {}
		_get('issue_statuses')['issue_statuses'].each do |status|
			hash[status['name']] = status
		end
		hash
	end

	def _get_group(name)
		_get('groups')['groups'].each do |group|
			next if group['name'] != name
			group = _get("groups/#{group['id']}", '?include=users')
			return group['group']
		end
		raise(ArgumentError, "No such group: #{name}")
	end

	def _get_custom_fields
		hash = {}
		_get('custom_fields')['custom_fields'].each do |field|
			hash[field['name']] = field
		end
		hash
	end

	def _get_value(field, value, dir)
		return value if ! field['possible_values']
		field['possible_values'].each do |pvalue|
			if pvalue[dir[0]] === value
				return pvalue[dir[1]]
			end
		end
		raise(ArgumentError, "Unknown value: #{value} for " +
		    "#{field['name']}")
	end

	def _convert_values(field, values, dir)
		ivalues = []
		values = [ values ] if ! values.respond_to?('each')
		values.each do |value|
			ivalues << _get_value(field, value, dir)
		end
		ivalues = ivalues[0] if field['multiple'] != 'true'
		ivalues
	end

	def _get_custom_field_value(name, value, dir)
		name = custom_field_name(name)
		field = @custom_fields[name]
		raise(ArgumentError, "Unknown field: #{name}") if ! field

		case field['field_format']
		when 'bool', 'string', 'text'
			# nothing
		when 'enumeration'
			value = _convert_values(field, value, dir)
		else
			raise(ArgumentError, "Unknown field format: " +
			    "#{field['field_format']}")
		end
		return field['id'], value
	end
end

end
