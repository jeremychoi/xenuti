# Copyright (C) 2014 Jan Rusnacko
#
# This copyrighted material is made available to anyone wishing to use,
# modify, copy, or redistribute it subject to the terms and conditions of the
# MIT license.

require 'spec_helper'
require 'helpers/git_helper'
require 'tmpdir'
require 'ruby_util/dir'

describe Xenuti::Repository do
  let(:config) do
    c = Xenuti::Config.new(File.new(FIXTURES_DIR + '/test_config.yml'))
    c.general.repo = ORIGIN_REPO
    c
  end

  it 'should check out repo to the latest version' do
    Dir.mktmpdir do |tmpdir|
      Xenuti::Repository.fetch_source(config, tmpdir)
      Dir.new(config.general.repo).should be_eql(Dir.new(tmpdir))
    end
  end

  it 'should update repo to the latest version' do
    Xenuti::Repository.fetch_source(config, OUTDATED_REPO)
    Dir.new(config.general.repo).should be_eql(Dir.new(OUTDATED_REPO))
  end
end