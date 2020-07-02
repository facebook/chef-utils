This file is intended to document the general principals behind how Facebook
thinks about and operates system configuration management. We think most of
these apply at any scale, but certainly make large scale easier.

# Guiding Principles

## Always keep basic scalable building blocks in mind

We try to always keep these basic scaling building blocks in mind:

* idempotent - it should be safe to run the system at any time and know
  it will only make the necessary changes
* distributed - the more work pushed to the clients, the better it scales.
* extensible - the easier it is to extend it for local requirements, the
  better it will work for any environment
* flexible - it needs to work with existing work flows, not dictate strict
  new ones

## Data-driven configuration

Full examples are available in [Facebook Chef
Cookbooks](https://github.com/facebook/chef-cookbooks)

Express your configuration as data as often as possible. For example, if you
express crons like:

```ruby
crons = {
  'backups' => {
    'timespec' => '12 01 * * *',
    'command' => '/usr/local/sbin/backups',
    'user' => 'root',
  },
}
```

It's easy set global defaults, and then build upon them in a way that provides
automatic inheritance. Global configs can define crons that need to be
everywhere, and other systems can simply add to those as necessary.  Someone
else can come along and do:

```ruby
crons['logrotate'] => {
  ...
}
```

In this way, you provide an API through which people may modify the parts of the
system they care about without having to own parts they don't care about or
understand.

## Manage systems idempotently, not records

Rather than manage individual records or entries (e.g. a cronjob, a sysctl),
manage an entire set or system of records as one idempotent entity.

To continue the example above, use the crons hash to generate
`/etc/cron.d/all_crons`. In this way all crons are created by the system as one
entity, so if someone deletes a line that added an entry to the hash, it is
automatically removed from the rendered config. If they modify a cron, it's
automatically modified. No need to try to match the old entry for removal.

## Delegating Delta Configuration

In order to scale the efforts of your people, it must be easy to delegate each
part of a system to the people who care most about that part.

Thus if the DBAs can control shared-memory on a database box and add some crons,
but at the same time don't have to own the entire `sysctl.conf` or worry about
merging their changes, then sysadmins don't have to understand all possible
sysctl combinations in the environment and DBAs don't have to know, say, what
ipv6 tunables the system needs.

# Examples

Facebook uses Chef to manage our systems and these examples are all in Chef and
assume a basic understanding of Chef. It is of course possible to build similar
systems with other software.

## Example 1: sysctl

We have a cookbook entitled `fb_sysctl` - and all paths in this example are
relative to that cookbook.

We start by building default hash of sysctls in `attributes/default.rb`

```ruby
default['fb_sysctl'] = {
  ...
}

if File.exists?('/proc/ipv6')
  {
    ...
  }.each do |sysctl, val|
    default['fb_sysctl'][sysctl] = val
  end
end
```

There's an entry in there for every entry you'd find in the RPM-provided file on
a RHEL system, many of them with tuned values based on data from Ohai.

Next we define a template for /etc/sysctl.conf in `recpies/default.rb` like so:

```ruby
template '/etc/sysctl.conf' do
  owner 'root'
  group 'root'
  mode '0644'
  notifies :run, 'execute[sysctl -p]'
end

execute 'sysctl -p' do
  action :nothing
end
```

Then we write that template, `templates/default/sysctl.conf.erb`:

```ruby
# This file is managed by Chef, do not modify directly.
<% node['fb_sysctl'].keys.sort.each do |sysctl| %>
<%=  sysctl %> = <% node['fb_sysctl'][sysctl] %>
<% end %>
```

Now we've defined defaults and an API. Now the DBAs, in the fb_mysql::server
recipe, for example, can do:

```ruby
node.default['fb_sysctl']['shm.max'] = ...
```

## Example 2: cron

This works similarly, but there's a bit more work to do... we have a cookbook
entitled fb_cron which defines some defaults in `attributes/default.rb`:

```ruby
default['fb_cron']['jobs'] = {
  'logrotate' => {
    'time' => ...
    'command' => '/usr/local/sbin/logrotate -d /etc/fb.logrotate',
  },
  ...
}
````

These are crons that should be on all boxes. Then in `recipes/default.rb`, we
do:

```ruby
template '/etc/cron.d/fb_crontab' do
  owner 'root'
  group 'root'
  mode '0755'
end
```

Now, in the template, we do some more intersting work. This is
`templates/defaults/fb_crontab.erb`:

```ruby
<% node['fb_crontab']['jobs'].to_hash.each do |name, job| %>
<%   # fill in defaults %>
<%   job['user'] = 'root' unless job['user'] %>
# <%=  name %>
<%   if job['mailto'] %>
MAILTO=<%= job['mailto'] %>
<%   end %>
<%=  job['time'] %> <%= job['user'] %> <%= command %>
<%   if job['mailto'] %>
MAILTO=root
<%   end %>

<% end %>
```

And again, now in other cookbooks people can add crons easily:

```ruby
node.default['fb_cron']['jobs']['mynewthing'] = {
  ...
}
```

# Other Considerations

We have a handful of considerations to accommodate our size which may or may not
be useful to others.

## Keeping multiple chef servers in sync

We have a chef server (or actually, set of servers) in each one of our clusters.
Each acts independently but must have its cookbooks and roles up-to-date. In
order to accomplish this we wrote
[Grocery Delivery](https://github.com/facebook/grocery-delivery).

Grocery Delivery runs on each Chef server (or Chef Backend if you use 'tier' or
'ha' mode in Enterprise Chef). It keeps a git or svn checkout of a repo of
cookbooks, and each time it is called it looks at what changed in the repo since
its last check and uses knife to upload/delete any cookbooks or roles as
necessary.

We run this in cron every minute to ensure all chef servers have the latest
cookbooks and roles.

It's important to note that if you have distributed Chef servers it is critical
to keep them in sync. Step one of that is ensuring that people do not modify the
contents of individual Chef servers directly. Keeping your servers in sync with
source code control provides a simple way of keeping them in sync while also
providing tracking for all changes.

## Trimming node.save()s

Due to the size of our clusters and the frequency with which we run Chef, saving
the node object back to the server isn't feasible.

Further, due to the way we manage multiple clusters and the fact that we have
pre-existing inventory management systems, saving node data to the chef server
also wasn't terribly important to us.

Finally, we want to treat chef servers as ephemeral, so persisting node data is
not practical.

Because of this we worked with Opscode/Chef to develop
[attribute whitelisting](https://docs.chef.io/nodes/#whitelist-attributes),
which will delete any entries from your node objects that aren't in a whitelist
prior to calling `node.save()`. Note that before Chef 11 this was implemented in
the [whitelist_node_attrs](https://github.com/opscode/whitelist-node-attrs)
cookbook.

## Treating Chef Servers as stateless commodities

In order to easily manage the many, many chef servers we have, we wanted to
treat them as stateless servers. Since we don't save node data to them, we were
already half way there. Grocery Delivery syncs cookbooks and roles, which gets
us 90% of the way there. We don't use databags, so that wasn't an issue. The
only thing left is runlists, and we enforce those on the client side by passing
in extra JSON attrs on the client side with a run_list defined. That run_list is
a template written out by Chef so it's easy to change.

## Monitoring

We have lots of different monitoring around Chef and hope to have more of it
open-sourced soon. At the moment the piece we have available is
chef-server-stats which can be found in our
[Chef Utilities repository](https://github.com/facebook/chef-utils).

Chef-server-stats - when run on a chef server - will determine what components
are running and then provide as many stats as possible from each of them, and
output a JSON object suitable for inserting into a variety of monitoring
systems.

# More

You can see our ChefConf keynote for other examples, graphs, and more details on
YouTube.
