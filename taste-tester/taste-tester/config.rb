# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require 'mixlib/config'

module TasteTester
  # Config file parser and config object
  # Uses Mixlib::Config v1 syntax so it works in Chef10 omnibus...
  # it's compatible with v2, so it should work in 11 too.
  module Config
    extend Mixlib::Config

    repo "#{ENV['HOME']}/ops"
    repo_type 'git'
    base_dir 'chef'
    cookbook_dirs ['cookbooks']
    role_dir 'roles'
    databag_dir 'databags'
    config_file '/etc/taste-tester-config.rb'
    plugin_path '/etc/taste-tester-plugin.rb'
    verbosity Logger::WARN
    timestamp false
    ref_file "#{ENV['HOME']}/.chef/taste-tester-ref.txt"
    checksum_dir "#{ENV['HOME']}/.chef/checksums"
    skip_repo_checks false
    chef_client_command 'chef-client'
    testing_time 3600
    use_ssh_tunnels true

    skip_pre_upload_hook false
    skip_post_upload_hook false
    skip_pre_test_hook false
    skip_post_test_hook false
    skip_repo_checks_hook false

    def self.cookbooks
      cookbook_dirs.map do |x|
        File.join(repo, base_dir, x)
      end
    end

    def self.relative_cookbook_dirs
      cookbook_dirs.map do |x|
        File.join(base_dir, x)
      end
    end

    def self.roles
      File.join(repo, base_dir, role_dir)
    end

    def self.relative_role_dir
      File.join(base_dir, role_dir)
    end

    def self.databags
      File.join(repo, base_dir, databag_dir)
    end

    def self.relative_databag_dir
      File.join(base_dir, databag_dir)
    end
  end
end
