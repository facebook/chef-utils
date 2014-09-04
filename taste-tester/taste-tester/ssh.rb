# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

module TasteTester
  # Thin ssh wrapper
  class SSH
    include TasteTester::Logging
    include BetweenMeals::Util

    attr_reader :output

    def initialize(host, timeout = 5, tunnel = false)
      @host = host
      @timeout = timeout
      @tunnel = tunnel
      @cmds = []
    end

    def add(string)
      @cmds << string
    end

    alias_method :<<, :add

    def run
      @status, @output = exec(cmd, logger)
    end

    def run!
      @status, @output = exec!(cmd, logger)
    rescue => e
      # rubocop:disable LineLength
      error = <<-MSG
SSH returned error while connecting to #{TasteTester::Config.user}@#{@host}
The host might be broken or your SSH access is not working properly
Try doing 'ssh -v #{TasteTester::Config.user}@#{@host}' and come back once that works
MSG
      # rubocop:enable LineLength
      error.lines.each { |x| logger.error x.strip }
      logger.error(e.message)
    end

    private

    def cmd
      @cmds.each do |cmd|
        logger.info("Will run: '#{cmd}' on #{@host}")
      end
      cmds = @cmds.join(' && ')
      cmd = "ssh -T -o BatchMode=yes -o ConnectTimeout=#{@timeout} "
      cmd += "#{TasteTester::Config.user}@#{@host} "
      if TasteTester::Config.user != 'root'
        cc = Base64.encode64(cmds).gsub(/\n/, '')
        cmd += "\"echo '#{cc}' | base64 --decode | sudo bash -x\""
      else
        cmd += "\'#{cmds}\'"
      end
      cmd
    end
  end
end
