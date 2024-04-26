# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
#
require_relative '../chefctl'

class ShellStub < Chefctl::Lib::Linux
  attr_accessor :cmd_output

  def shell_output(_cmd, &_block)
    @cmd_output
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
      skip 'not working'
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
      skip 'not working'
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
