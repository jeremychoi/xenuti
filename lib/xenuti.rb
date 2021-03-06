# Copyright (C) 2014 Jan Rusnacko
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of the
# MIT license.

def xfail(message)
  $log.error message
  fail message
end

module Xenuti
end

require 'xenuti/version'
require 'xenuti/config'
require 'xenuti/script_report'
require 'xenuti/warning'
require 'xenuti/report'
require 'xenuti/report_sender'
# require 'xenuti/backends/content_update'
# require 'xenuti/backends/git'
# require 'xenuti/backends/bugzilla_flaws'
require 'xenuti/processor'
