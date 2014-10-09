fb_sysctl Cookbook
====================
This cookbook provides sysctl functionality to Chef users. Below is how to set
sysctls in your own cookbooks.

Requirements
------------

Attributes
----------
* node['fb']['fb_sysctl']

Usage
-----
Anywhere, in any cookbook, you can set a sysctl in a recipe as follows:

    node.default['fb']['fb_sysctl'][$SYSCTL] = $VALUE

For example, vm.swappiness can be set to 1 to tell the kernel to only
application data if it is necessary.

    node.default['fb']['fb_sysctl']['vm.swappiness'] = 1

License
-------
```text
Copyright:: 2014-present, Facebook, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
