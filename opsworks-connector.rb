#!/usr/bin/env ruby

require 'fog'
require 'optparse'

options = {}

class String
  def red;            "\033[31m#{self}\033[0m" end
  def green;          "\033[32m#{self}\033[0m" end
end

OptionParser.new do |opts|
  opts.on("-s", "--stack STACK", "What stack to use") do |stack|
    options[:stack] = /#{stack}/
  end

  opts.on("-h", "--host HOST", "What host to use") do |host|
    options[:host] = host
  end

  opts.on("-l", "--list", "List stacks and instances") do |list|
    options[:list] = list
  end
end.parse!

conn = Fog::Compute.new(provider: 'aws', aws_access_key_id: ENV['S3_ACCESS_KEY_ID'], aws_secret_access_key: ENV['S3_SECRET_ACCESS_KEY'])

if options[:list]
  conn.servers.group_by { |server| server.tags['opsworks:stack'] }.reject{|stack,_| ['',nil].include?(stack)}.each do |stack, servers|
    puts "Stack: #{stack}"
    puts "============"

    servers.sort_by{|server| server.tags['opsworks:instance'] }.each do |server|
      state_indicator = server.state == 'running' ? server.state.green : server.state.red
      puts "\t#{server.tags['opsworks:instance']} (#{state_indicator})"
    end
    puts "\n"
  end

  exit 0
end

if options.empty? && ARGV.size == 2
  options[:stack] = /#{ARGV[0]}/
  options[:host] = ARGV[1]
  options[:host_pattern] = /#{ARGV[1]}/
end

unless options[:host] && options[:stack]
  puts "Supply all arguments"
  exit 1
end

instance = conn.servers.find do |server|
  server.tags['opsworks:stack'] =~ options[:stack] &&
  (server.tags['opsworks:instance'] == options[:host] || server.tags['opsworks:instance'] =~ options[:host_pattern] ) &&
  server.state == 'running'
end

unless instance
  puts "Can't find #{options[:host]} in stack like #{options[:stack]}"
  exit 1
end

unless instance.private_ip_address
  puts "No IP address found for instance."
  puts instance.inspect
  exit 1
end

cmd = "slogin ubuntu@#{instance.private_ip_address}"
puts cmd
exec cmd
