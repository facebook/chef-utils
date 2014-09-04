# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

module TasteTester
  # Thin ssh tunnel wrapper
  class Tunnel
    include TasteTester::Logging
    include BetweenMeals::Util

    attr_reader :port

    def initialize(host, server, timeout = 5)
      @host = host
      @server = server
      @timeout = timeout
      if TasteTester::Config.testing_until
        @delta_secs = TasteTester::Config.testing_until.strftime('%s').to_i -
          Time.now.strftime('%s').to_i
      else
        @delta_secs = TasteTester::Config.testing_time
      end
    end

    def run
      @port = TasteTester::Config.tunnel_port
      logger.info("Setting up tunnel on port #{@port}")
      @status, @output = exec!(cmd, logger)
    rescue
      logger.error 'Failed bringing up ssh tunnel'
      exit(1)
    end

    def cmd
      cmds = "echo \\\$\\\$ > #{TasteTester::Config.timestamp_file} &&" +
      " touch -t #{TasteTester::Config.testing_end_time}" +
      " #{TasteTester::Config.timestamp_file} && sleep #{@delta_secs}"
      cmd = "ssh -T -o BatchMode=yes -o ConnectTimeout=#{@timeout} " +
        "-o ExitOnForwardFailure=yes -f -R #{@port}:localhost:" +
        "#{@server.port} root@#{@host} \"#{cmds}\""
      cmd
    end

    def self.kill(name)
      ssh = TasteTester::SSH.new(name)
      # Since commands are &&'d together, and we're using &&, we need to
      # surround this in paryns, and make sure as a whole it evaluates
      # to true so it doesn't mess up other things... even though this is
      # the only thing we're currently executing in this SSH.
      ssh << "( [ -s #{TasteTester::Config.timestamp_file} ]" +
        " && kill -- -\$(cat #{TasteTester::Config.timestamp_file}); true )"
      ssh.run!
    end
  end
end
