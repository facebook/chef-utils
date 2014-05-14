fb_cron Cookbook
====================
This cookbook provides a simple data-based API for setting crons.

Requirements
------------

Attributes
----------
* node['fb']['fb_cron']['jobs']

Usage
-----
### Adding Jobs
`node['fb']['fb_cron']['jobs']` is a hash of crons. To add a job, simply do:

    node.default['fb']['fb_cron']['jobs']['do_this_thing'] = {
      'time' => '4 5 * * *',
      'user' => 'serviceuser',
      'command' => '/usr/local/bin/foo.sh',
    }

Please name your cronjob as follows:
* simple string
* no spaces
* underscores instead of dashes

This deleting it in other code easier if necessary. See 'Removing Jobs' for
details.

You can also specify `mailto` to direct mail for your job.

`user` is optional and will default to 'root', but `time` and `command`
are required.

### Removing Jobs
To remove a job you added, simply stop adding it to the hash.  This cookbook
makes cron idempotent *as a whole*, thus if you remove the lines adding a cron
job, it'll be removed from any systems it was on.

A bunch of default crons we want everywhere are set in the attributes file, if
you need to exempt yourself from one, you can simply remove it from the hash:

    node['fb']['fb_cron']['jobs'].delete('do_this_thing')

For this reason, cron jobs should be given simple names as described above
to make exempting systems easy.

NOTE: These jobs will end up in /etc/cron.d/fb_crontab
WARNING: This cookbook wipes out /var/spool/cron/root

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
