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
    options[:host_pattern] = /#{host}/
  end

  opts.on("-c", "--command COMMAND", "What command to run on the matching host(s)") do |cmd|
    options[:command] = cmd
  end

  opts.on("-l", "--list", "Just list the servers") do
    options[:list] = true
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

potential = conn.servers.select do |server| 
  server.tags['opsworks:stack'] =~ options[:stack] && 
  (server.tags['opsworks:instance'] == options[:host] || server.tags['opsworks:instance'] =~ options[:host_pattern] ) &&
  server.state == 'running'
end

ssh_options = "-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"
if options[:list]
  potential.each {|i| puts i.tags['opsworks:instance'] }
elsif options[:command]
  if potential.empty?
    puts "Can't find any matching hosts"
    exit
  elsif
    potential.each do |instance|
      puts instance.tags['opsworks:instance']
      puts %x(slogin #{ssh_options} ubuntu@#{instance.private_ip_address} "#{options[:command]}")
    end
  end

else
  instance = potential.find do |server|
    server.tags['opsworks:instance'] == ARGV[1]
  end


  instance ||= potential.first

  unless instance
    puts "Can't find #{options[:host]} in stack like #{options[:stack]}"  
    exit 1
  end

  unless instance.private_ip_address
    puts "No IP address found for instance."
    puts instance.inspect
    exit 1
  end


  cmd = "slogin #{ssh_options} ubuntu@#{instance.private_ip_address}"
  puts cmd
  exec cmd
end
