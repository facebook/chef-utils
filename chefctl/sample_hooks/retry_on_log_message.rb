# This hook file is located at '/etc/chef/chefctl_hooks.rb'
# You can change this location by passing `-p/--plugin-path` to `chefctl`,
# or by setting `plugin_path` in `chefctl-config.rb`

# Below is a sample hook file that will rerun chef if chef fails and a
# particular message (in this case, `Try again!`) is found in the chef log.
#
# Hook descriptions and empty hooks have been removed. Refer to the hook
# documentation for descriptions of each method.

module RetryOnLogMessage
  def rerun_chef?(output, chef_exitcode)
    # Don't retry if chef passed
    return false if chef_exitcode == 0

    # Look for `Try again!` in the chef log.
    need_retry = false
    File.foreach(output) do |line|
      if /Try again!/ =~ line
        need_retry = true
        break
      end
    end
    need_retry
  end
end

Chefctl::Plugin.register RetryOnLogMessage
