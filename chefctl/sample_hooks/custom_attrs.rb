# Copyright 2013-present Facebook
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
      attrs = { 'custom_attributes' => @custom_attr }
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
