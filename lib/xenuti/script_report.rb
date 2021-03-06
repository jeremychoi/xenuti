# Copyright (C) 2014 Jan Rusnacko
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of the
# MIT license.

require 'ruby_util/hash'
require 'ruby_util/string'
require 'ruby_util/hash_with_method_access'
require 'ruby_util/hash_with_constraints'
require 'yaml'

class Xenuti::ScriptReport < Hash
  include HashWithMethodAccess

  def self.sort_messages(field, messages)
    return messages if messages.any? {|message| !message.is_a? Hash }
    return messages if messages.any? { |message| message[field].nil? }
    return messages.sort_by { |message| message[field]}
  end

  def initialize
    self['scan_info'] = {
      'start_time' => nil, 'end_time' => nil, 'script_name' => nil,
      'version' => nil, 'exception' => nil, 'relpath' => '',
      'mode' => 'full report', 'args' => nil, 'revision' => nil }

    self['old_report'] = {}
    self['messages'] = []
  end

  def formatted(config)
    report = formatted_header
    report << formatted_messages(config) unless scan_info['exception']
    report
  end

  # rubocop:disable CyclomaticComplexity
  def formatted_header
    header = '=' * 55 + "\n"
    unless scan_info.relpath == ''
      header << "directory:      #{scan_info.relpath}\n"
    end
    header << formatted_header_info
    header << formatted_header_diffed_with if diffed?
    header << "total messages: #{messages.size}\n" unless scan_info['exception']
    header << formatted_header_diff_msg if diffed? && !scan_info['exception']
    header << formatted_header_exception if scan_info['exception']
    header << '=' * 55 + "\n\n"
  end
  # rubocop:enable CyclomaticComplexity

  def formatted_header_info
    <<-EOF.unindent
      script:         #{scan_info['script_name']}
      version:        #{scan_info['version']}
      duration:       #{duration} s
      arguments:      #{scan_info['args']}
      mode:           #{diffed? ? 'diff results' : 'full report'}

    EOF
  end

  def formatted_header_exception
    "\nERROR: " + self['scan_info']['exception'].message + "\n"
  end

  def formatted_header_diffed_with
    h = <<-EOF.unindent
      [diffed with]
      start time:     #{self['old_report']['start_time']}
    EOF
    if old_report['revision']
      h <<  "revision:       #{self['old_report']['revision']}"
    end
    h << "\n"
  end

  def formatted_header_diff_msg
    <<-EOF.unindent
      new messages:   #{self['new_messages'].size}
      fixed messages: #{self['fixed_messages'].size}
    EOF
  end

  def formatted_messages(config)
    output = ''
    warns_to_print = diffed? ? self['new_messages'] : self['messages']
    if warns_to_print.size == 0
      output << "No messages.\n"
    else
      script_name = self['scan_info']['script_name']
      sort_field = config['process'][script_name]['sort_field']
      $log.warn sort_field
      if(sort_field)
        warns_to_print = Xenuti::ScriptReport.sort_messages(sort_field, warns_to_print)
      end
      output << warns_to_print.map{|m| format_message(m)}.join("\n" + '-'*55 + "\n\n")
    end
    output
  end

  # rubocop:disable MethodLength
  def format_message(message)
    return message if message.is_a? String
    if message.is_a? Array
      return message.join("\n")
    elsif message.is_a? Hash
      out = ''
      key_maxlen = message.key_maxlen + 1
      message.each do |k, v|
        out << format("%-#{key_maxlen}s %s\n", k + ':', v) unless v.nil?
      end
      return out
    else
      $log.error "Message must be String, Array or Hash, is: #{message.class}"
      return ''
    end
  end
  # rubocop:enable MethodLength

  def diff!(old_report, ignore_fields=[])
    if old_report.nil? || old_report['messages'].nil? ||
        old_report['scan_info'].nil? || old_report['scan_info']['start_time'].nil?
      $log.error 'Diffing with old report failed: old report possibly malformed'
      return self
    end

    ignore_fields = [ignore_fields] if ignore_fields.is_a? String

    self['new_messages'] = self['messages'].select do |msg_new|
      old_report['messages'].all? do |msg_old|
        (msg_new.keys - ignore_fields).any? do |k|
          msg_new[k] != msg_old[k]
        end
      end
    end

    self['fixed_messages'] = old_report['messages'].select do |msg_old|
      self['messages'].all? do |msg_new|
        (msg_old.keys - ignore_fields).any? do |k|
          msg_old[k] != msg_new[k]
        end
      end
    end

    self.old_report['start_time'] = old_report['scan_info']['start_time']
    if old_report['scan_info']['revision']
      self.old_report['revision'] = old_report['scan_info']['revision']
    end

    self['scan_info']['mode'] = 'diff results'

    self
  end

  def diffed?
    return true if self['new_messages'] && self['fixed_messages']
    false
  end

  def duration
    (scan_info.end_time - scan_info.start_time).round(2)
  end

  def empty?
    return self['new_messages'].empty? if diffed?
    return self.messages.empty?
  end
end
