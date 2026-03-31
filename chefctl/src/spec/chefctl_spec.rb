# Copyright 2024-present Meta Platforms, Inc. and affiliates
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'tempfile'
require_relative '../chefctl'

class ShellStub < Chefctl::Lib::Linux
  attr_accessor :cmd_output

  def shell_output(cmd, &_block)
    # Force list_processes into the 2-column (pid, command) branch
    if cmd.include?('pidns')
      raise Mixlib::ShellOut::ShellCommandFailed # rubocop:todo Style/SignalException
    end
    @cmd_output
  end

  private

  # Avoid real ps calls for parent tree lookups
  def parent_group(_pid)
    [Process.pid]
  end
end

RSpec.describe Chefctl::Lib do
  def lib
    Chefctl::Lib::Linux.new
  end

  describe '#shell_output' do
    it 'should say hello' do
      expect(lib.shell_output('echo hello world')).to eq("hello world\n")
    end

    it 'should evaluate in a real shell' do
      expect(lib.shell_output(
               "echo -n 'hello ' | sed 's/h/j/' ; echo -n world",
      )).to eq('jello world')
    end
  end

  describe '#get_timestamp' do
    it 'should return a valid timestamp format' do
      # Format is YYYYMMDD.HHMM.S*
      expect(lib.get_timestamp).to match(/[0-9]{8}.[0-9]{4}.[0-9]*/)
    end
  end

  describe '#chefctl_procs' do
    it 'should return chef process' do
      lib = ShellStub.new
      lib.cmd_output = [
        '123 chefctl.rb foo bar',
        '234 chefctl.sh -i -s 500',
        '345 foobar.baz',
        '456 ruby /foo/bar/chefctl.rb -foo bar',
        '567 chef-client --local-mode',
      ].join("\n")
      expect(lib.chefctl_procs).to eq([123, 234, 456])
    end

    it 'should filter editors' do
      lib = ShellStub.new
      lib.cmd_output = [
        '123 emacs chefctl.rb',
        '234 vi chefctl.sh',
        '345 ruby chefctl.rb',
        '456 vim /foo/bar/chefctl.rb',
      ].join("\n")
      expect(lib.chefctl_procs).to eq([345])
    end
  end
end

RSpec.describe Chefctl::Main do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  it 'acquires lock if lockfile if file is appendable' do
    expect(main).to receive(:wait_for_lock).with(-1).and_call_original # first attempt
    lockfile = double('lockfile')

    # open 'a+' done in wait_for_lock
    allow(File).to receive(:open).with('/var/lock/subsys/chefctl', 'a+') { lockfile }
    allow(lockfile).to receive(:flock).and_return(true)

    allow(lockfile).to receive(:close)
    expect(lockfile).to receive(:truncate)
    expect(Process).to receive(:pid).and_return('123123')
    expect(lockfile).to receive(:write).with('123123')
    expect(lockfile).to receive(:flush)
    main.acquire_lock
  end

  it 'can still acquire lock if first attempt fails' do
    # First failed attempt
    allow(Chefctl).
      to receive_message_chain(:logger, :debug).with('Trying lock /var/lock/subsys/chefctl')
    allow(main).to receive(:wait_for_lock).with(-1).and_return(false)

    # Second attempt
    expect(main).to receive(:wait_for_lock).with(1800).and_call_original # second attempt

    # Get pid of other lock file
    other_lockfile = double('other_lockfile')
    expect(File).to receive(:open).with('/var/lock/subsys/chefctl', 'r').and_yield(other_lockfile)
    expect(other_lockfile).to receive(:read).and_return('888888')

    expect(Chefctl).
      to receive_message_chain(:logger, :info).
      with('/var/lock/subsys/chefctl is locked by 888888, waiting up to 1800 seconds.')

    # open 'a+' done in wait_for_lock
    lockfile = double('lockfile')
    allow(File).to receive(:open).with('/var/lock/subsys/chefctl', 'a+') { lockfile }
    allow(lockfile).to receive(:flock).and_return(true)

    # taking over the lock
    expect(Chefctl).
      to receive_message_chain(:logger, :debug).with('Lock acquired: /var/lock/subsys/chefctl')
    expect(lockfile).to receive(:truncate)
    expect(Process).to receive(:pid).and_return('123123')
    expect(lockfile).to receive(:write).with('123123')
    expect(lockfile).to receive(:flush)

    main.acquire_lock
  end

  it 'can still acquire lock if first attempt fails' do
    # First failed attempt
    allow(Chefctl).
      to receive_message_chain(:logger, :debug).with('Trying lock /var/lock/subsys/chefctl')
    allow(main).to receive(:wait_for_lock).with(-1).and_return(false)

    # Second attempt
    expect(main).to receive(:wait_for_lock).with(1800).and_call_original # second attempt

    # Get pid of other lock file
    other_lockfile = double('other_lockfile')
    expect(File).to receive(:open).with('/var/lock/subsys/chefctl', 'r').and_yield(other_lockfile)
    expect(other_lockfile).to receive(:read).and_return('888888')

    expect(Chefctl).
      to receive_message_chain(:logger, :info).
      with('/var/lock/subsys/chefctl is locked by 888888, waiting up to 1800 seconds.')

    # open 'a+' done in wait_for_lock
    lockfile = double('lockfile')
    allow(File).to receive(:open).with('/var/lock/subsys/chefctl', 'a+') { lockfile }
    allow(lockfile).to receive(:flock).and_return(true)

    # taking over the lock
    expect(Chefctl).
      to receive_message_chain(:logger, :debug).with('Lock acquired: /var/lock/subsys/chefctl')
    expect(lockfile).to receive(:truncate)
    expect(Process).to receive(:pid).and_return('123123')
    expect(lockfile).to receive(:write).with('123123')
    expect(lockfile).to receive(:flush)

    main.acquire_lock
  end

  it 'does not crash on race between wait_for_lock and read on missing lockfile' do
    # First failed attempt
    allow(Chefctl).
      to receive_message_chain(:logger, :debug).with('Trying lock /var/lock/subsys/chefctl')
    allow(main).to receive(:wait_for_lock).with(-1).and_return(false)

    # Second attempt
    expect(main).to receive(:wait_for_lock).with(1800).and_call_original # second attempt

    # Attempt to get pid of other lock file
    expect(File).to receive(:open).with('/var/lock/subsys/chefctl', 'r').and_raise(Errno::ENOENT)
    expect(Chefctl).
      to receive_message_chain(:logger, :info).
      with('Possible lockfile race, re-running wait_for_lock')

    expect(Chefctl).
      to receive_message_chain(:logger, :info).
      with('/var/lock/subsys/chefctl is locked by another process, waiting up to 1800 seconds.')

    # open 'a+' done in wait_for_lock
    lockfile = double('lockfile')
    allow(File).to receive(:open).with('/var/lock/subsys/chefctl', 'a+') { lockfile }
    allow(lockfile).to receive(:flock).and_return(true)

    # taking over the lock
    expect(Chefctl).
      to receive_message_chain(:logger, :debug).with('Lock acquired: /var/lock/subsys/chefctl')
    expect(lockfile).to receive(:truncate)
    expect(Process).to receive(:pid).and_return('123123')
    expect(lockfile).to receive(:write).with('123123')
    expect(lockfile).to receive(:flush)

    main.acquire_lock
  end
end

RSpec.describe Chefctl::Main, 'locking with disable_locking' do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  around do |example|
    original = Chefctl::Config.disable_locking
    Chefctl::Config.disable_locking true
    example.run
  ensure
    Chefctl::Config.disable_locking original
  end

  it 'acquire_lock is a no-op when disable_locking is true' do
    expect(main).not_to receive(:wait_for_lock)
    main.acquire_lock
  end

  it 'release_lock is a no-op when disable_locking is true' do
    lock_fd = double('lock_fd')
    main.instance_variable_get(:@lock)[:fd] = lock_fd
    main.instance_variable_get(:@lock)[:held] = true
    expect(lock_fd).not_to receive(:flock)
    expect(lock_fd).not_to receive(:close)
    expect(File).not_to receive(:unlink)
    main.release_lock
  end

  it 'lock still yields the block when locking is disabled' do
    # Stub to prevent filesystem access if disable_locking guard fails
    allow(File).to receive(:open).with('/var/lock/subsys/chefctl', anything).
      and_raise('locking should be disabled')
    yielded = false
    main.lock { yielded = true }
    expect(yielded).to eq(true)
  end
end

RSpec.describe Chefctl::Lib, '#validate_options' do
  let(:lib) { Chefctl::Lib::Linux.new }

  it 'accepts valid options' do
    expect { lib.validate_options(:splay => 100) }.not_to raise_error
  end

  it 'accepts empty options' do
    expect { lib.validate_options({}) }.not_to raise_error
  end

  it 'exits when both splay and immediate are set' do
    expect do
      lib.validate_options(:splay => 100, :immediate => true)
    end.to raise_error(SystemExit)
  end
end

RSpec.describe Chefctl::Lib, '#chef_client_binary' do
  let(:lib) { Chefctl::Lib::Linux.new }

  around do |example|
    original = Chefctl::Config.chef_client
    example.run
  ensure
    Chefctl::Config.chef_client original
  end

  it 'returns the string when chef_client is a string' do
    Chefctl::Config.chef_client '/usr/bin/chef-client'
    expect(lib.chef_client_binary).to eq('/usr/bin/chef-client')
  end

  it 'returns the first element when chef_client is an array' do
    Chefctl::Config.chef_client ['/usr/bin/ruby', '--disable-gems', '/usr/bin/chef-client']
    expect(lib.chef_client_binary).to eq('/usr/bin/ruby')
  end
end

RSpec.describe Chefctl::Lib, '#set_mtime' do
  let(:lib) { Chefctl::Lib::Linux.new }

  it 'sets the mtime of a file' do
    tmpfile = Tempfile.new('set_mtime_test')
    new_time = Time.now - 3600
    lib.set_mtime(tmpfile.path, new_time)
    expect(File.mtime(tmpfile.path).to_i).to eq(new_time.to_i)
  ensure
    tmpfile.close!
  end
end

RSpec.describe Chefctl::Main, '#get_chef_cmd' do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  around do |example|
    saved = {
      :chef_client => Chefctl::Config.chef_client,
      :debug => Chefctl::Config.debug,
      :trace => Chefctl::Config.trace,
      :human => Chefctl::Config.human,
      :whyrun => Chefctl::Config.whyrun,
      :color => Chefctl::Config.color,
      :chef_options => Chefctl::Config.chef_options.dup,
    }
    example.run
  ensure
    saved.each { |k, v| Chefctl::Config.send(k, v) }
  end

  it 'returns default command with force-logger and no-color' do
    Chefctl::Config.debug false
    Chefctl::Config.trace false
    Chefctl::Config.human false
    Chefctl::Config.whyrun false
    Chefctl::Config.color false
    Chefctl::Config.chef_options ['--no-fork']
    cmd = main.get_chef_cmd
    expect(cmd).to include('--force-logger')
    expect(cmd).to include('--no-color')
    expect(cmd).to include('--no-fork')
  end

  it 'includes debug flags when debug is true' do
    Chefctl::Config.debug true
    Chefctl::Config.trace false
    Chefctl::Config.human false
    Chefctl::Config.whyrun false
    Chefctl::Config.color false
    Chefctl::Config.chef_options []
    cmd = main.get_chef_cmd
    expect(cmd).to include('-l', 'debug')
  end

  it 'includes trace flags when trace is true' do
    Chefctl::Config.debug false
    Chefctl::Config.trace true
    Chefctl::Config.human false
    Chefctl::Config.whyrun false
    Chefctl::Config.color false
    Chefctl::Config.chef_options []
    cmd = main.get_chef_cmd
    expect(cmd).to include('-l', 'trace')
  end

  it 'includes why-run flag when whyrun is true' do
    Chefctl::Config.debug false
    Chefctl::Config.trace false
    Chefctl::Config.human false
    Chefctl::Config.whyrun true
    Chefctl::Config.color false
    Chefctl::Config.chef_options []
    cmd = main.get_chef_cmd
    expect(cmd).to include('--why-run')
    expect(cmd).to include('-l', 'fatal')
    expect(cmd).to include('-F', 'doc')
  end

  it 'omits --no-color when color is true' do
    Chefctl::Config.debug false
    Chefctl::Config.trace false
    Chefctl::Config.human false
    Chefctl::Config.whyrun false
    Chefctl::Config.color true
    Chefctl::Config.chef_options []
    cmd = main.get_chef_cmd
    expect(cmd).not_to include('--no-color')
  end
end

RSpec.describe Chefctl::Main, '#get_chef_env' do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  it 'sets HOSTNAME from the plugin' do
    env = main.get_chef_env
    expect(env).to have_key('HOSTNAME')
  end

  it 'sets PATH from config' do
    env = main.get_chef_env
    expect(env).to have_key('PATH')
    Chefctl::Config.path.each do |p|
      expect(env['PATH']).to include(p)
    end
  end

  it 'passes through allowed env vars' do
    original = ENV['HOME']
    env = main.get_chef_env
    expect(env['HOME']).to eq(original) if original
  end
end

RSpec.describe Chefctl::Main, '#keep_testing' do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  around do |example|
    original = Chefctl::Config.testing_timestamp
    example.run
  ensure
    Chefctl::Config.testing_timestamp original
  end

  it 'extends testing when stamp expires in less than 1 hour' do
    tmpfile = Tempfile.new('test_timestamp')
    Chefctl::Config.testing_timestamp tmpfile.path
    # Set mtime to 30 minutes from now (< 1 hour)
    future = Time.now + 1800
    File.utime(File.atime(tmpfile.path), future, tmpfile.path)

    main.keep_testing

    # mtime should now be ~1 hour from now
    new_mtime = File.mtime(tmpfile.path)
    expect(new_mtime.to_i).to be_within(5).of((Time.now + 3600).to_i)
  ensure
    tmpfile.close!
  end

  it 'does nothing when stamp file does not exist' do
    Chefctl::Config.testing_timestamp '/nonexistent/path/test_timestamp'
    expect { main.keep_testing }.not_to raise_error
  end
end

RSpec.describe Chefctl::Main, '#symlink_output' do
  let(:main) { Chefctl::Main.new('/var/chef/outputs', 'foo') }

  around do |example|
    original = Chefctl::Config.symlink_output
    example.run
  ensure
    Chefctl::Config.symlink_output original
  end

  it 'does not create symlink when symlink_output is false' do
    Chefctl::Config.symlink_output false
    expect(Chefctl.lib).not_to receive(:symlink)
    main.symlink_output(:chef_cur)
  end
end

RSpec.describe TwoPassParser do
  it 'should perform two passes' do
    n = 0
    p = TwoPassParser.new do |parser|
      parser.on('-foo') do
        n += 1
      end
    end
    p.parse_both_passes(['-foo']) { |_p| }
    expect(n).to eq(2)
  end

  it 'should parse arguments in the first pass' do
    first = false
    p = TwoPassParser.new do |parser|
      parser.on('-first') do
        next unless parser.first_pass
        first = true
      end
    end
    p.parse_both_passes(['-first']) { |_p| }
    expect(first).to eq(true)
  end

  it 'should parse arguments in the second pass' do
    second = false
    p = TwoPassParser.new do |parser|
      parser.on('-second') do
        next if parser.first_pass
        second = true
      end
    end
    p.parse_both_passes(['-second']) { |_p| }
    expect(second).to eq(true)
  end

  it 'should parse arguments in both passes' do
    second = first = false
    p = TwoPassParser.new do |parser|
      parser.on('-first') do
        next unless parser.first_pass
        first = true
      end

      parser.on('-second') do
        next if parser.first_pass
        second = true
      end
    end
    p.parse_both_passes(['-first', '-second']) { |_p| }
    expect(first).to eq(true)
    expect(second).to eq(true)
  end

  it 'should parse dynamic arguments the second pass' do
    n = 0
    first_pass = nil
    p = TwoPassParser.new do |parser|
    end
    p.parse_both_passes(['-dynamic']) do
      p.on('-dynamic') do
        n += 1
        first_pass = p.first_pass
      end
    end
    expect(n).to eq(1)
    expect(first_pass).to eq(false)
  end
end
