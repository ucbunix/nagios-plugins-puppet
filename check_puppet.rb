#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'ostruct'

UNITS = %w[seconds minutes hours]
UNIT_ALIASES = { 'd' => 'days', 'h' => 'hours', 'm' => 'minutes',
                 's' => 'seconds' }

to_s = { :days => 86400, :hours => 3600, :minutes => 60, :seconds => 1 } 

options = OpenStruct.new
options.units = :hours
options.warn = 0
options.warn_set = false
options.crit = 0
options.crit_set = false
options.verbose = 0
options.file = "/var/lib/puppet/state/last_run_summary.yaml"

begin
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0}"
    unit_list = (UNIT_ALIASES.keys + UNITS).join(',')
    opts.on("-u", "--units UNIT", UNITS, UNIT_ALIASES,
            "Select units of measurement", "   (#{unit_list})") do |unit|
      options.units = unit.to_sym
    end

    opts.on("-w", "--warn [TIME]",Integer,
            "time since last run that results in warning status") do |w|
      options.warn = w
      options.warn_set = true
    end

    opts.on("-c", "--crit [TIME]",Integer,
            "time since last run that results in critical status") do |c|
      options.crit = c
      options.crit_set = true
    end

    opts.on("-v", "--verbose",Integer, "increase output verbosity") do |v|
      options.verbose += 1
    end

    opts.on("-f", "--file [FILENAME]", String, "Puppet state file") do |f|
      options.file = f
    end
  end.parse!
rescue => e
  puts e
end

options.warn = to_s[options.units] * options.warn
options.crit = to_s[options.units] * options.crit

if options.crit < options.warn
  puts "Warning threshold must be less than critical!"
  puts "#{options.warn} > #{options.crit}"
  exit 1
end

begin
  summary = YAML::load_file(options.file)
rescue
  puts "Unable to read input!"
  exit 1
end
now = Time.now.to_i

since = now - summary['time']['last_run']

nag_code = { :ok => 0, :warning => 1, :critical => 2, :unknown => 3 }
state = :ok
info = "We're all fine here now, thank you. How are you?"

if since >= options.warn and options.warn_set
  state = :warning
  info = "#{since} > #{options.warn}"
end

if since >= options.crit and options.crit_set
  state = :critical
  info = "#{since} > #{options.crit}"
end

# follow http://nagiosplug.sourceforge.net/developer-guidelines.html#PLUGOUTPUT
perf_state = state.to_s.upcase
puts "Agent " + perf_state + " - #{info}|since=#{since}s;#{options.warn};#{options.crit};;"
if options.verbose > 0
  # print out verbosity = 1
  puts "time_total=#{summary['time']['total']}"
end

if options.verbose > 1
  # print out verbosity = 2
  puts "resources=#{summary['resources']['total']}"
end
