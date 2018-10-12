require 'mongo'

# XXX
class Time
	def to_s
		self.strftime('%Y/%m/%d %T')
	end
end

module SOC

module Mongo
	ACCT_JITTER = 5 * 60
	ACCT_INTERVAL = 60 * 60
	ACCT_OFFSET = ACCT_INTERVAL + ACCT_JITTER

	ARP_JITTER = 2 * 60
	ARP_INTERVAL = 5 * 60
	ARP_OFFSET = ARP_INTERVAL + ARP_JITTER

	::Mongo::Logger.logger.level = Logger::INFO

	def _arp(addr, time, key, off)
		mc = ::Mongo::Client.new(
		    ARP_URL,
		    user: 'arp_user', password: ARP_PASSWD)
		options =  { key => addr, }
		if time && off
			options[:time] = { '$lte': time + off }
			options[:lastseen] = { '$gte': time - off }
		end
		if key === :user_ip
			valuekey = :user_mac
		else
			valuekey = :user_ip
		end

		v = nil
		lastseen = nil
		mc[:arplog].find(options).each do |arp|
			if v.nil? ||
			   (time - arp[:lastseen]).abs < (time - lastseen).abs
				v = arp[valuekey]
				lastseen = arp[:lastseen]
			end
		end
		raise("No ARP entry found for #{addr} on #{time}") if ! v
		v
	end

	def arp(ia, time, off = ARP_OFFSET)
		_arp(ia, time, :user_ip, off)
	end
	private :arp

	def rarp(ma, time, off = ARP_OFFSET)
		_arp(ma, time, :user_mac, off)
	end
	private :rarp

	def acct_start(collection, addr, time, key)
		mc = ::Mongo::Client.new(
		    RADIUS_URL,
		    user: RADUIS_USER, password: RADIUS_PASSWD)

		options = {
		    key => addr,
		    '$or': [
		        { act: 'Connect' },
			{ act: 'Update' },
		        { act: 'Disconnect' }
		        ],
                        }
		if time
			# XXX: currently, interim update is disabled on wired LAN...
#			options[:time] = { '$lte': time, '$gte': time - ACCT_OFFSET }
			options[:time] = { '$lte': time }
		end
		recent = nil
		mc[collection].find(options).each do |acct|
			if ! recent
				recent = acct
			elsif recent[:time] < acct[:time]
				recent = acct
			end
		end
		if ! recent || (! time.nil? && recent[:act] == 'Disconnect')
			raise("No #{collection.to_s} entry found for #{addr}")
		end
		# convert time stored in MongoDB in UTC to local time.
		recent[:time] = recent[:time].localtime
		recent
	end
	private :acct_start

	def acct_wired
		if @ia
			@ma = arp(@ia, @time)
		else
			@ia = rarp(@ma, @time)
		end
		acct = acct_start(:wiredaccounting, @ma, @time, :user_mac)
		@nas = acct[:sw_name]
		@nasia = acct[:sw_ip]
		@nasport = acct[:port]
		@starttime = acct[:time]
		@session_id = acct[:session_id]
	end

	def acct_wireless
		if @ia
			addr = @ia
			key = :user_ip
		else
			addr = @ma
			key = :user_mac
		end
		acct = acct_start(:accounting, addr, @time, :user_mac)
		@ia = acct[:user_ip]
		@ma = acct[:user_mac]
		@nas = acct[:ap_name]
		@nasport = acct[:port]
		@starttime = acct[:time]
		@session_id = acct[:session_id]
		@userid = acct[:toridai_id]
	end

	# XXX
	class Users
		include Enumerable

		class User
			attr_reader :id, :name, :lastseentime

			def initialize(id, lastseentime, name)
				@id = id
				@name = @name
				#
				# convert time stored in MongoDB in UTC
				# to local time.
				#
				@lastseentime = lastseentime.localtime
			end

			def recent_than?(other, time)
				return false if other.nil?
				(@lastseentime - time).abs <
				    (other.lastseentime - time).abs
			end
		end

		def initialize(ia, iakey, time, off, url, user, password,
		    collection, *additional_filter)
			@users = {}

			filter = { iakey => ia }
			if time
				filter[:time] = {
				    '$gte': time - off, '$lte': time + off }
			end
			# XXX: i do not know how to evaluate variable arguments.
			if ! additional_filter.empty?
				filter = filter.merge(additional_filter[0])
			end
			mc = ::Mongo::Client.new(url,
			    user: user, password: password)
			mc[collection.to_sym].find(filter).each do |e|
				userid = e[:toridai_id]
				# XXX: only for dovecot...sigh...
				userid = e[:user_id] if userid.nil?
			    	add(userid, e[:time], e[:username], time)
			end
			raise("No login found for #{ia} on #{time}") if empty?
		end

		def add(id, lastseentime, name, time)
			raise if id.nil?
			user = User.new(id, lastseentime, name)
			if user.recent_than?(@users[user.id], time)
				return
			end
			@users[user.id] = user
		end

		def empty?
			@users.empty?
		end

		def each
			@users.each do |id, user|
				yield user
			end
		end
	end

	IDP_JITTER = 10 * 60
	IDP_LOGIN_EXPIRY = 2 * 60 * 60 + IDP_JITTER

	def idp(ia, time)
		Users.new(ia, :user_ip, time, IDP_LOGIN_EXPIRY,
		    IDP_URL,
		    IDP_USER, IDP_PASSWD, :authlog)
	end
	module_function :idp

	GAROON_JITTER = 10 * 60
	GAROON_COOKIE_EXPIRY = 2 * 60 * 60 + GAROON_JITTER

	def garoon(ia, time)
		Users.new(ia, :host_ip, time, GAROON_COOKIE_EXPIRY,
		    GAROON_URL,
		    GAROON_USER, GAROON_PASSWD, :authlog,
		    grn_act: ':grn.common:notice:[login]')
	end
	module_function :garoon

	DOVECOT_EXPIRY = 7 * 24 * 60 * 60

	def dovecot(ia, time)
		Users.new(ia, :client_ip, time, DOVECOT_EXPIRY,
		    DOVECOT_URL,
		    DOVECOT_USER, DOVECOT_PASSWD, :dovecot,
		    act: :Login)
	end
	module_function :dovecot
end

end
