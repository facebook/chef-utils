#!/opt/chef/embedded/bin/ruby
# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
# rubocop:disable UnusedBlockArgument, AlignParameters

require 'rubygems'
require 'time'
require 'optparse'
require 'colorize'

require_relative 'taste-tester/logging'
require_relative 'taste-tester/config'
require_relative 'taste-tester/commands'
require_relative 'taste-tester/hooks'

include TasteTester::Logging

if ENV['USER'] == 'root'
  logger.info 'You should not be running as root'
  exit(1)
end

# Command line parsing and param descriptions
module TasteTester
  verify = 'Verify your changes were actually applied as intended!'.red
  cmd = TasteTester::Config.command
  description = <<-EOF
Welcome to taste-tester!

Usage: taste-tester <mode> [<options>]

TLDR; Most common usage is:
  vi cookbooks/...             # Make your changes and commit locally
  taste-tester test -s [host]  # Put host in taste-tester mode
  ssh root@[host]              # Log in to host
    #{cmd} # Run chef and watch it break
  vi cookbooks/...             # Fix your cookbooks
  taste-tester upload          # Upload the diff
  ssh root@[host]
    #{cmd} # Run chef and watch it succeed
  <#{verify}>
  taste-tester untest [host]   # Put host back in production
                               #   (optional - will revert itself after 1 hour)

And you're done! See the above wiki page for more details.

MODES:
  test
    Sync your local repo to your virtual Chef server (same as 'upload'), and
    point some production server specified by -s to your virtual chef server for
    testing.  If you have you a plugin that uses the hookpoint, it'll may amend
    your commit message to denote the server you tested.

  upload
    Sync your local repo to your virtual Chef server (i.e. just the first step
    of 'test'). By defailt, it intelligently uploads whatever has changed since
    the last time you ran upload (or test), but tracking git changes (even
    across branch changes). You may specify -f to force a full upload of all
    cookbooks and roles. It also does a fair amount of sanity checking on
    your repo and you may specify --skip-repo-checks to bypass this.

  keeptesting
    Extend the testing time on server specified by -s by 1 hour unless
    otherwise specified by -t.

  untest
    Return the server specified in -s to production.

  status
    Print out the state of the world.

  run
    Run #{cmd} on the machine specified by '-s' over SSH and print the output.
    NOTE!! This is #{'NOT'.red} a sufficient test, you must log onto the remote
    machine and verify the changes you are trying to make are actually present.

  stop
    You probably don't want this. It will shutdown the chef-zero server on
    your localhost.

  start
    You probably don't want this. It will start up the chef-zero server on
    your localhost. taste-tester dynamically starts this if it's down, so there
    should be no need to do this manually.

  restart
    You probably don't want this. It will restart up the chef-zero server on
    your localhost. taste-tester dynamically starts this if it's down, so there
    should be no need to do this manually.
  EOF

  mode = ARGV.shift unless ARGV.size > 0 && ARGV[0].start_with?('-')

  unless mode
    mode = 'help'
    puts "ERROR: No mode specified\n\n"
  end

  options = { :config_file => TasteTester::Config.config_file }
  parser = OptionParser.new do |opts|
    opts.banner = description

    opts.separator ''
    opts.separator 'Global options:'.upcase

    opts.on('-c', '--config FILE', 'Config file') do |file|
      unless File.exists?(File.expand_path(file))
        logger.error("Sorry, cannot find #{file}")
        exit(1)
      end
      options[:config_file] = file
    end

    opts.on('-d', '--debug', 'Verbose output') do
      options[:debug] = true
    end

    opts.on('-p', '--plugin-path FILE', String, 'Plugin file') do |file|
      unless File.exists?(File.expand_path(file))
        logger.error("Sorry, cannot find #{file}")
        exit(1)
      end
      options[:plugin_path] = file
    end

    opts.on('-h', '--help', 'Print help message.') do
      print opts
      exit
    end

    opts.on('-T', '--timestamp', 'Time-stamped log style output') do
      options[:timestamp] = true
    end

    opts.separator ''
    opts.separator 'Sub-command options:'.upcase

    opts.on(
      '-C', '--cookbooks COOKBOOK[,COOKBOOK]', Array,
      'Specific cookbooks to upload. Intended mostly for debugging,' +
        ' not recommended. Works on upload and test. Not yet implemented.'
    ) do |cbs|
      options[:cookbooks] = cbs
    end

    opts.on(
      '-D', '--databag DATABAG/ITEM[,DATABAG/ITEM]', Array,
      'Specific cookbooks to upload. Intended mostly for debugging,' +
        ' not recommended. Works on upload and test. Not yet implemented.'
    ) do |cbs|
      options[:databags] = cbs
    end

    opts.on(
      '-f', '--force-upload',
      'Force upload everything. Works on upload and test.'
    ) do
      options[:force_upload] = true
    end

    opts.on(
      '-l', '--linkonly', 'Only setup the remote server, skip uploading.'
    ) do
      options[:linkonly] = true
    end

    opts.on(
      '-t', '--testing-timestamp TIME',
        'Until when should the host remain in testing.' +
        ' Anything parsable is ok, such as "5/18 4:35" or "16/9/13".'
    ) do |time|
      begin
        options[:testing_until] = Time.parse(time)
      rescue
        logger.error("Invalid date: #{time}")
        exit 1
      end
    end

    opts.on(
      '-t', '--testing-time TIME',
        'How long should the host remain in testing.' +
        ' Takes a simple relative time string, such as "45m", "4h" or "2d".'
    ) do |time|
      m = time.match(/^(\d+)([d|h|m]+)$/)
      if m
        exp = {
          :d => 60 * 60 * 24,
          :h => 60 * 60,
          :m => 60,
        }[m[2].to_sym]
        delta = m[1].to_i * exp
        options[:testing_until] = Time.now + delta.to_i
      else
        logger.error("Invalid testing-time: #{time}")
        exit 1
      end
    end

    opts.on(
      '-r', '--repo DIR',
      "Custom repo location, current deafult is #{TasteTester::Config.repo}." +
        ' Works on upload and test.'
    ) do |dir|
      options[:repo] = dir
    end

    opts.on(
      '-R', '--roles ROLE[,ROLE]', Array,
      'Specific roles to upload. Intended mostly for debugging,' +
        ' not recommended. Works on upload and test. Not yet implemented.'
    ) do |roles|
      options[:roles] = roles
    end

    opts.on('--really', 'Really do link-only. DANGEROUS!') do |r|
      options[:really] = r
    end

    opts.on(
      '-s', '--servers SERVER[,SERVER]', Array,
      'Server to test/untest/keeptesting.'
    ) do |s|
      options[:servers] = s
    end

    opts.on('--skip-repo-checks', 'Skip repository sanity checks') do
      options[:skip_repo_checks] = true
    end

    opts.on('-y', '--yes', 'Do not prompt before testing.') do
      options[:yes] = true
    end

    opts.separator ''
    opts.separator 'Control local hook behavior with these options:'

    opts.on(
      '--skip-pre-upload-hook', 'Skip pre-upload hook. Works on upload, test.'
    ) do
      options[:skip_pre_upload_hook] = true
    end

    opts.on(
      '--skip-post-upload-hook', 'Skip post-upload hook. Works on upload, test.'
    ) do
      options[:skip_post_upload_hook] = true
    end

    opts.on(
      '--skip-pre-test-hook', 'Skip pre-test hook. Works on test.'
    ) do
      options[:skip_pre_test_hook] = true
    end

    opts.on(
      '--skip-post-test-hook', 'Skip post-test hook. Works on test.'
    ) do
      options[:skip_post_test_hook] = true
    end

    opts.on(
      '--skip-repo-checks-hook', 'Skip repo-checks hook. Works on upload, test.'
    ) do
      options[:skip_post_test_hook] = true
    end
  end

  if mode == 'help'
    puts parser
    exit
  end

  parser.parse!

  if File.exists?(File.expand_path(options[:config_file]))
    TasteTester::Config.from_file(File.expand_path(options[:config_file]))
  end
  TasteTester::Config.merge!(options)
  TasteTester::Logging.debug = TasteTester::Config.debug
  TasteTester::Logging.use_log_formatter = TasteTester::Config.timestamp

  if File.exists?(File.expand_path(TasteTester::Config.plugin_path))
    TasteTester::Hooks.get(File.expand_path(TasteTester::Config[:plugin_path]))
  end

  case mode.to_sym
  when :start
    TasteTester::Commands.start
  when :stop
    TasteTester::Commands.stop
  when :restart
    TasteTester::Commands.restart
  when :keeptesting
    TasteTester::Commands.keeptesting
  when :status
    TasteTester::Commands.status
  when :test
    TasteTester::Commands.test
  when :untest
    TasteTester::Commands.untest
  when :run
    TasteTester::Commands.runchef
  when :upload
    TasteTester::Commands.upload
  else
    logger.error("Invalid mode: #{mode}")
    puts parser
    exit(1)
  end
end

if __FILE__ == $PROGRAM_NAME
  include TasteTester
end
