# This hook file is located at '/etc/chef/chefctl_hooks.rb'
# You can change this location by passing `-p/--plugin-path` to `chefctl`,
# or by setting `plugin_path` in `chefctl-config.rb`

# Below is a sample hook file that will set a custom node attribute based on a
# command line flag and call the chef-client process with that custom attribute.
#
# Hook descriptions and empty hooks have been removed. Refer to the hook
# documentation for descriptions of each method.

require 'json'

module CustomAttributes
  def initialize
    @tmp_file = nil
    @custom_attr = nil
  end

  def cli_options(parser)
    parser.on(
      '--custom-attr',
      'A custom node attribute',
    ) do |v|
      @custom_attr = v
    end
  end

  def pre_start
    if @custom_attr
      @tmp_file = Tmpfile.new('attributes')
      attrs = {'custom_attributes' => @custom_attr}
      @tmp_file.write(JSON.generate(attrs))
      @tmp_file.close
      Chefctl::Config.chef_options += ['-j', @tmp_file.path]
    end
  end

  def post_run(_output, _chef_exitcode)
    @tmp_file.unlink if @tmp_file
  end
end

Chefctl::Plugin.register CustomAttributes
