
require 'redis'
require "resolv"

def redis
  @redis ||= begin
               vip = running_config["private_chef"]["redis_lb"]["vip"]
               port = running_config["private_chef"]["redis_lb"]["port"]
               password = credentials.get('redis_lb', 'password')
               Redis.new(port: port, ip: vip, password: password)
             end
end

def enable_maintenance
  puts "- Enabling maintenance mode"
  redis.hset("dl_default", "503_mode", true)
end

def disable_maintenance
  puts "- Disabling maintenance mode"
  redis.hdel("dl_default", "503_mode")
end

def add_ip_to_whitelist(ip)
  validate_ip(ip)
  puts "- Adding #{ip} to whitelist."
  redis.sadd("maint_whitelisted_ip", ip)
end

def remove_ip_from_whitelist(ip)
  validate_ip(ip)
  puts "- Removing #{ip} from whitelist."
  redis.srem("maint_whitelisted_ip", ip)
end

def validate_ip(ip)
  isIPv4 = ip =~ Resolv::IPv4::Regex ? true : false
  isIPv6 = ip =~ Resolv::IPv6::Regex ? true : false
  unless isIPv4 or isIPv6
    $stderr.puts "The IP address is invalid, please enter valid IP address"
    exit 1
  end
end


add_command_under_category "maintenance", "general", "Handel the server properly while maintenance", 2 do
  args = ARGV[1..-1] # Chop off first 1 args, keep the rest... that is, everything after "chef-server-ctl maintenance"
  options = {}

  if args[0] == 'on'
    enable_maintenance
    args = args[1..-1]
  elsif args[0] == 'off'
    disable_maintenance
    args = args[1..-1]
  elsif args.length == 0
    $stderr.puts "Please specify the action 'on' or 'off' or pass the maintenance options"
    exit 1
  end

  OptionParser.new do |opts|

    # even if you enable in the redis you have to refresh the shared_dict of nginx lua or reduce the maint_refresh_interval
    opts.on("-a", "--add-ip [String]", "Add an IP to whitelist") do |a|
      options[:add_ip] = a
    end

    opts.on("-r", "--remove-ip [String]", "Remove an IP from the whitelist") do |a|
      options[:remove_ip] = a
    end
  end.parse!(args)

  add_ip_to_whitelist(options[:add_ip]) if options[:add_ip]
  remove_ip_from_whitelist(options[:remove_ip]) if options[:remove_ip]

end