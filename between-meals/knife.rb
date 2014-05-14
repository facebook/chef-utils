# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'json'
require 'fileutils'
require_relative 'util'

module BetweenMeals
  # Knife does not have a usable API for using it as a lib
  # This could be possibly refactored to touch its internals
  # instead of shelling out
  class Knife
    include BetweenMeals::Util

    def initialize(opts = {})
      @logger = opts[:logger] || nil
      @user = opts[:user] || ENV['USER']
      @home = opts[:home] || ENV['HOME']
      @host = opts[:host] || 'localhost'
      @port = opts[:port] || 4000
      @config = opts[:config] ||
        "#{@home}/.chef/knife-#{@user}-taste-tester.rb"
      @knife = opts[:bin] || 'knife'
      @pem = opts[:pem] ||
        "#{@home}/.chef/#{@user}-taste-tester.pem"
      @role_dir = opts[:role_dir]
      @cookbook_dirs = opts[:cookbook_dirs]
      @databag_dir = opts[:databag_dir]
      @checksum_dir = opts[:checksum_dir]
      @client_key =
        File.expand_path("#{@home}/.chef/#{@user}-taste-tester.pem")
    end

    def role_upload_all
      roles = File.join(@role_dir, '*.rb')
      exec!("#{@knife} role from file #{roles} -c #{@config}", @logger)
    end

    def role_upload(roles)
      if roles.any?
        roles = roles.map { |x| File.join(@role_dir, "#{x.name}.rb") }.join(' ')
        exec!("#{@knife} role from file #{roles} -c #{@config}", @logger)
      end
    end

    def role_delete(roles)
      if roles.any?
        roles.each do |role|
          exec!(
            "#{@knife} role delete #{role.name} --yes -c #{@config}", @logger
          )
        end
      end
    end

    def cookbook_upload_all
      exec!("knife cookbook upload -a -c #{@config}", @logger)
    end

    def cookbook_upload(cookbooks)
      if cookbooks.any?
        cookbooks = cookbooks.map { |x| x.name }.join(' ')
        exec!("#{@knife} cookbook upload #{cookbooks} -c #{@config}", @logger)
      end
    end

    def cookbook_delete(cookbooks)
      if cookbooks.any?
        cookbooks.each do |cookbook|
          exec!("#{@knife} cookbook delete #{cookbook.name}" +
                  " --purge --yes -c #{@config}", @logger)
        end
      end
    end

    def databag_upload_all
      glob = File.join(@databag_dir, '*', '*.json')
      items = Dir.glob(glob).map do |file|
        BetweenMeals::Changes::Databag.new(
          { :status => :modified, :path => file }, @databag_dir
        )
      end
      databag_upload(items)
    end

    def databag_upload(databags)
      if databags.any?
        databags.group_by { |x| x.name }.each do |dbname, dbs|
          create_databag_if_missing(dbname)
          dbitems = dbs.map do |x|
            File.join(@databag_dir, dbname, "#{x.item}.json")
          end.join(' ')
          exec!("#{@knife} data bag from file #{dbname} #{dbitems}", @logger)
        end
      end
    end

    def databag_delete(databags)
      if databags.any?
        databags.group_by { |x| x.name }.each do |dbname, dbs|
          dbs.each do |db|
            exec!("#{@knife} data bag delete #{dbname} #{db.item}" +
                    " --yes -c #{@config}", @logger)
          end
          delete_databag_if_empty(dbname)
        end
      end
    end

    def write_user_config
      # rubocop:disable LineLength
      cfg = <<-BLOCK
user = ENV['USER']
log_level :info
log_location STDOUT
node_name user
chef_server_url "http://#{@host}:#{@port}"
cache_type 'BasicFile'
client_key #{@client_key}
cache_options(:path => File.expand_path("#{@checksum_dir}"))
cookbook_path [
BLOCK
      @cookbook_dirs.each do |dir|
        cfg << "  \"#{dir}\",\n"
      end
      cfg << "]\n"
      # rubocop:enable LineLength
      unless File.exists?(@config)
        @logger.debug("Generating #{@config}")
        File.write(@config, cfg)
      end

      # Won't work with shorter keys
      pem = <<-BLOCK
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCs4Ih8+R/2hcYS
tccwJHd0cXHcUibC2wGYmRwf1fKxXLADvfuLRVBHOI5Hgd/ZXF70dowC5mDQ03gr
ouk8e7RL72MCKzPuG2V92sh/FnyKhkNsHCOEKaRRiP9lHVbZkS9LEotCKF7eOkL0
SVkGWx8pVZzrOFmhZgHaOFJ2/2t1irUTRFqTikrRsP2KvnhHdDlnnbUumZWxSuEN
oN6aSAQEOkKbEOLSn/EIMzEb2jtks7L7wkRErajH094jGoZbQvLiwRHDeM0C9uG7
2sdQ45BG9EQOCdBzy1We5keqtJbXBcpwuBa0d1nQZIsGxnDb88+Kmh9h6k9/WmYN
zEQEeSSdAgMBAAECggEATFWQru4p6ObEwTo2y9EuVeJJzmkP6HZfzAu/WWdVFG/C
4MQgsCxY+DnGyVhViVq6KuO1iwpCsbLOmyYCKszMncMESs7czUSXmezjHwrEzz3d
w3zhSdhBUCdX7kP4N3VeFp4Hk5zT1viO2+MPRjkyF0RQV6S4HwY1xy+baiP6RRnS
dGhUYsdz6fjxSkYEQy3/xHm9VLT6ZDV4pN2aA+LOFeveHKcnOjKFCBy4WzkO6fvj
6H3jghxsHXoL7loCHfi9WX3xKjeXG/NjGbUfTH8P7IldUPha+ru/e8W/P+jjE1os
VkScWt08Vu6iTl1EkYeFxOMtSDZxeXNnDkPI0iDQgQKBgQDUMFYncQcZ4uLIfoZq
B+Lx7WJGlIwulOdobnraTd5lsrBHj1sC1+/f4cBSpJwUij2l3GdmmnOpuFAof5eu
mrBGu++5jy+0eIeT5O2d30O8GOBryJ+oAKI2/BPVCmM8d986wl5Esauycb++O7UO
RhpZFOCKbFvlNjhg+CdlvHSl7QKBgQDQkkvpnE//yWmhCPg27n7w3bTg5QPNrzTO
pF2iwvLK4XjRceTeW3P4f42HONzJNnmt5TexM9NbdE9g/exA5uNt59ZB5FeFiKAu
NmVXbmswPX6R/dlyidqzz1guGrL04e0dZehHZBNDr5Sio8IBjMWrpDIxjDJqEwUa
4qCu4e6jcQKBgQDN0FTAzRFmOnxenNsj3aJzpx27+DpAtI4A7aicNwuQ+VGjF5nf
mDRDpGU3xBLgmXZSewaQrx+hb/XQUnJ+Ge0BrylHg2tyUbav7U3N49F/kWGdKmwy
OOsfCkLyUbEP5fXQuNdXKj6wR0UE8EUeI0FLRsTFf3VjTsRAynLsa295wQKBgAo3
QDSfDWQP73aNw+qc3+bYVSW20erfLAz7DAMO3WmGha5sj7M8c3+2b64x4M6SNn+H
/KRXT4DpP4IWrd238WfOtTXhA1BtErtwuqH/rIxeVra74kyz59xqyXzond9UuZJ5
DVmB01e7X+Jfdv8wb/YqQrMelNGRQOzCMPCf7FphAoGAbUh5HzNF2aciQJGA6Qk8
zvgEHqbS0/QkJGOZ+UifPRanTDuGYQkPdHHOER4UghbM+Kz5rZbBicJ3bCyNOsah
IAMAEpsWX2s2A6phgMCx7kH6wMmoZn3hb7Thh9+PfR8Jtp2/7k+ibCeF4gEWUCs5
6wX4GR84dwyhG80yd4TP8Qo=
-----END PRIVATE KEY-----
    BLOCK

      unless File.exists?(@pem)
        @logger.debug("Generating #{@pem}")
        File.write(@pem, pem)
      end
    end

    private

    def create_databag_if_missing(databag)
      s = Mixlib::ShellOut.new("#{@knife} data bag list" +
                               " --format json -c #{@config}").run_command
      s.error!
      db = JSON.load(s.stdout)
      unless db.include?(databag)
        exec!("#{@knife} data bag create #{databag} -c #{@config}", @logger)
      end
    end

    def delete_databag_if_empty(databag)
      s = Mixlib::ShellOut.new("#{@knife} data bag show #{databag}" +
                               " --format json -c #{@config}").run_command
      s.error!
      db = JSON.load(s.stdout)
      if db.empty?
        exec!("#{@knife} data bag delete #{databag} --yes -c #{@config}",
              @logger)
      end
    end
  end
end
