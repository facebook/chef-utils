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
      prepare
      @status, @output = exec(@cmd, logger)
    end

    def run!
      prepare
      @status, @output = exec!(@cmd, logger)
    rescue => e
      error = <<-MSG
SSH returned error while connecting to root@#{@host}
The host might be broken or your SSH access is not working properly
Try doing 'ssh -v root@#{@host}' and come back once that works
MSG
      error.lines.each { |x| logger.error x.strip }
      logger.error(e.message)
    end

    private

    def prepare
      @cmds.each do |cmd|
        logger.debug "Will run: '#{cmd}' on #{@host}"
      end
      cmds = @cmds.join(' && ')
      @cmd = "ssh -T -o BatchMode=yes -o ConnectTimeout=#{@timeout} "
      if @tunnel
        @cmd += ' -f -R 4001:localhost:4000 '
      end
      @cmd += "root@#{@host} \"#{cmds}\""
    end
  end
end
