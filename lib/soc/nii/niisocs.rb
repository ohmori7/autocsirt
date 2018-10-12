# -*- encoding: utf-8 -*-

require 'net/http'
require 'openssl'
require 'nokogiri'

# XXX: SOCS cannot be used here because it is plural of SOC...

class NIISOCS
	URL_FQDN = 'portal.soc.nii.ac.jp'
	URL_PATH_LOGIN = '/ada/view/clientLogin/index.xhtml'
	URL_PATH_SESSION = '/ada/view/SessionInfoList/index.xhtml'
	URL_PATH_ALARM = '/ada/view/AlarmMailHistory/index.xhtml'
	URL_PATH_ALARM_DETAIL = '/ada/view/' +
	    'TargetedCyberAttackAlarmInformationDetail/dialog.xhtml'

	def initialize
		cert = File.read(NII_SOCS_CLIENT_CERTIFICATE)
		key  = File.read(NII_SOCS_CLIENT_KEY)
		options = {
		    use_ssl:		true,
		    verify_mode:	OpenSSL::SSL::VERIFY_PEER,
		    keep_alive_timeout:	30,
		    cert:		OpenSSL::X509::Certificate.new(cert),
		    key: 		OpenSSL::PKey::RSA.new(key)
		    }
		@http = Net::HTTP.start(URL_FQDN, 443, options)
		login
	end

	def cookie_parse(cookies)
		return if cookies.nil?
		cookies.each do |cookie|
			if cookie =~ /^JSESSIONID=([^;]+);.*$/
				@cookie = $1
				return
			end
		end
		raise('No cookie sent for NII-SOCS')
	end
	private :cookie_parse

	def cookie
		return nil if @cookie.nil?
		return "JSESSIONID=#{@cookie}"
	end

	def path(path)
#		if ! @cookie.nil?
#			path += ";jsessionid=#{@cookie}"
#		end
		path
	end
	private :path

	def code_check(response, code)
		case response
		when code
		else
			raise("unexpected response #{response} for NII-SOCS")
		end
	end
	private :code_check

	def get(path, code = Net::HTTPOK)
		get = Net::HTTP::Get.new(path(path))
		# XXX: may not be necessary but browser does this...
		get['Cookie'] = cookie
		response = @http.request(get)
		code_check(response, code)
		cookie_parse(response.get_fields('set-cookie'))
		response
	end
	private :get

	def post(path, params, code = Net::HTTPOK)
		params['jsessionid'] = @cookie
		post = Net::HTTP::Post.new(path(path))
		post['Cookie'] = cookie
		post.set_form_data(params)
		response = @http.request(post)
		code_check(response, code)
		cookie_parse(response.get_fields('set-cookie'))
		response
	end
	private :post

	def login
		response = get(URL_PATH_LOGIN)
		doc = Nokogiri::HTML(response.body)
		viewstate = doc.css('input#j_id1\:javax\.faces\.ViewState\:1')
		viewstatevalue = viewstate.first.attributes['value'].value
		response = post(URL_PATH_LOGIN, {
		    'j_idt33' => 'j_idt33',
		    'j_idt33:account' => NII_SOCS_USERNAME,
		    'j_idt33:password' => NII_SOCS_PASSWORD,
		    'j_idt33:buttonLogin' => 'j_idt33:buttonLogin',
		    'javax.faces.ViewState' => viewstatevalue,
		    },
		    Net::HTTPFound)
	end
	private :login

	def session_get(sessionid)
		# XXX
	end

	def alarm_get(alarmid)
		#
		# many things just in order to obtain ticket ID...
		#
		response = get(URL_PATH_ALARM)
		doc = Nokogiri::HTML(response.body)
		viewstate = doc.css('input#j_id1\:javax\.faces\.ViewState\:2')
		viewstatevalue = viewstate.first.attributes['value'].value
		response = post(URL_PATH_ALARM, {
		    'lazyTableForm' => 'lazyTableForm',
		    'lazyTableForm:j_idt54_collapsed' => 'false',
		    'lazyTableForm:AlarmMailHistoryViewTable_selection' => '',
		    'lazyTableForm:AlarmMailHistoryViewTable_scrollState' => '0,0',
		    'javax.faces.ViewState' => viewstatevalue,
		    'lazyTableForm:alarmId_hinput' => alarmid,
		    'lazyTableForm:alarmId_input' => alarmid,
		    'lazyTableForm:j_idt78' => 'lazyTableForm:j_idt78',
		    })
		doc = Nokogiri::HTML(response.body)
		t = doc.css('#lazyTableForm\:AlarmMailHistoryViewTable_data td')
		ticketid = t[6].children.to_s

		#
		# alarm information can be easily obtained.
		#
		response = get(URL_PATH_ALARM_DETAIL +
		    "?alarmid=#{alarmid}")
		doc = Nokogiri::HTML(response.body)
		table = doc.css('table#j_idt36\:j_idt38').first
		tbody = table.xpath('tbody').first
		keys = [ 'チケット番号' ]
		values = {
		    'チケット番号' => ticketid,
		    'title'        => doc.title }
		tbody.xpath('tr').each do |tr|
			key = tr.xpath('td')[0].text.to_s
			children = tr.xpath('td')[1].children.first
			if children.is_a?(Nokogiri::XML::Text)
				value = children.to_s
			else
				value = nil
			end
			keys.push(key)
			values[key] = value
		end
		return keys, values
	end
end
