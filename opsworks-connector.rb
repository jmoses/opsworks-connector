#!/usr/bin/env ruby

require 'fog'
require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.on("-s", "--stack STACK", "What stack to use") do |stack|
    options[:stack] = /#{stack}/
  end

  opts.on("-h", "--host HOST", "What host to use") do |host|
    options[:host] = host
  end
end.parse!

if options.empty? && ARGV.size == 2
  options[:stack] = /#{ARGV[0]}/
  options[:host] = ARGV[1]
  options[:host_pattern] = /#{ARGV[1]}/
end

unless options[:host] && options[:stack]
  puts "Supply all arguments"
  exit 1
end

conn = Fog::Compute.new(provider: 'aws')

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
