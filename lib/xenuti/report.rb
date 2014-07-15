# Copyright (C) 2014 Jan Rusnacko
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of the
# MIT license.

require 'ruby_util/hash_with_method_access'
require 'ruby_util/hash_with_constraints'
require 'date'

# Xenuti::Report is a subclass of Hash - this makes life easier for things like
# formatting, serialization and calculating difference of two reports.
#
# General structure report is simple:
#
#  {
#    :scan_info => {},
#    :scanner_reports => []
#  }
#
# :scan_info holds hash with general information about the scan, while
# :scanner_reports points to an Array of Xenuti::ScannerReports. Moreover, it
# also has one attribute :diffed, which indicates whether the report is result
# of a diff between two other reports.
#
# Also includes HashWithMethodAccess, which makes it possible to access values
# in two ways:
#
#     report[:scan_info][:version]
#     report.scan_info.version
#
# This works by overloading #method_missing and returning value of the key if
# key of such name exists. If the key of such name does not exists,
# NoMethodError is thrown.
#
# Such method has two gotchas:
# * New keys cannot be defined, hash syntax must be used
# * Names of keys may collide with actual method names
#
# When possible, I use this method cause it just seems nice to me.
#
# Additionally, HashWithConstraints module is also included. This makes it
# possible to specify a block with constraints passed to #constraints method,
# and invoke check calling #check method. This works only if blocks passed raise
# errors. If constraints should not be saved, but we need one-time-only check,
# use #verify method.
class Xenuti::Report < Hash
  include HashWithMethodAccess
  include HashWithConstraints

  attr_accessor :diffed

  REPORT_NAME = 'report.yml'

  # Load report saved by #save method.
  def self.load(filename)
    # TODO: figure out SafeYAML to call this with safe: true
    YAML.load(File.new(filename).read, safe: false)
  end

  # Returns the oldest report that can be found in Xenuti`s workdir, as defined
  # in configuration.
  def self.prev_report(config)
    search_path = File.join(config.general.workdir, '/reports/**/', REPORT_NAME)
    reportfiles = Dir.glob search_path
    latest_time = Time.at(0)
    latest = nil
    reportfiles.each do |reportfile|
      report = load(reportfile)
      latest = report[:scan_info][:start_time] > latest_time ? report : latest
      latest_time = latest.scan_info.start_time
    end
    latest
  end

  # Returns new report, which is a result of calculating difference of two other
  # reports. Diffed report contains :scan_info of newer report, but also some
  # info about older report (such as revision, on which it ran).
  #
  # Most importantly, all scanner reports also contain :new_warnings and
  # :fixed_warnings keys, which point to Array of Xenuti::Warnings (see
  # Xenuti::ScannerReport::diff).
  def self.diff(old_report, new_report)
    report = Xenuti::Report.new
    report.scan_info = new_report.scan_info
    new_report.scanner_reports.each do |new_sr|
      scanner_name = new_sr.scan_info.scanner_name
      old_sr = Xenuti::Report.find_scanner_report(old_report, scanner_name)
      report.scanner_reports << Xenuti::ScannerReport.diff(old_sr, new_sr)
    end
    report.diffed = true
    report.old_report = old_report
    report
  end

  # Finds scanners report corresponding to the scanner_name.
  def self.find_scanner_report(report, scanner_name)
    report.scanner_reports.select do |r|
      r.scan_info.scanner_name == scanner_name
    end.first
  end

  def self.reports_dir(config)
    timestamp = Time.now.to_datetime.rfc3339
    @@dir ||= File.join(config.general.workdir, 'reports', timestamp)
  end

  def initialize
    self[:scan_info] = { version: Xenuti::Version }
    self[:scanner_reports] = []
    @diffed = false
  end

  # Retrieve again with Xenuti::Report.load(filename).
  def save(config)
    unless Dir.exist? Xenuti::Report.reports_dir(config)
      FileUtils.mkdir_p Xenuti::Report.reports_dir(config)
    end
    filename = File.join(self.class.reports_dir(config), REPORT_NAME)
    File.open(filename, 'w+') do |file|
      file.write(YAML.dump(self))
    end
  end

  # Returns plaintext pretty-formatted version of a report.
  def formatted(config)
    report = formatted_header(config)
    scanner_reports.each do |scanner_report|
      report << scanner_report.formatted + "\n"
    end
    report
  end

  def formatted_header(config)
    header = <<-EOF.unindent
    #######################################################
                        XENUTI REPORT
    #######################################################
    EOF
    header << formatted_header_scan_info + "\n"
    header << formatted_header_config_info(config) + "\n"
    header << formatted_header_diff_info + "\n" if diffed?
    header << formatted_header_end_banner + "\n"
  end

  def formatted_header_scan_info
    <<-EOF.unindent
    version:    #{scan_info.version}
    start time: #{scan_info.start_time}
    end time:   #{scan_info.end_time}
    duration:   #{duration} s
    mode:       #{diffed? ? 'diff results' : 'full report'}
    EOF
  end

  def formatted_header_config_info(config)
    <<-EOF.unindent
    name:       #{config.general.name}
    repo:       #{config.general.repo}
    revision:   #{config.general.revision}
    EOF
  end

  def formatted_header_diff_info
    <<-EOF.unindent
    [diffed with]
    start time: #{old_report.scan_info.start_time}
    revision:   #{old_report.scan_info.revision}
    EOF
  end

  def formatted_header_end_banner
    '#' * 55 + "\n"
  end

  def duration
    (scan_info.end_time - scan_info.start_time).round(2)
  end

  def diffed?
    # TODO: get rid of unnecessary attribute. Report is diffed when it contains
    # reference to old_report and all scanner reports are diffed. Also update
    # doc text above.
    @diffed == true
  end
end
