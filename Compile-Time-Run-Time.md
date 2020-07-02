# Compile Time vs Run Time, and APIs

This document covers the Chef two-phase run system, specifically geared towards
how that interacts with the API model we use with Chef at Facebook. If you're
not familiar with our model, you should read our
[Philosophy](https://github.com/facebook/chef-utils/blob/master/Philosophy.md)
document and our
[Cookbooks README.md](https://github.com/facebook/chef-cookbooks/blob/master/README.md)
first. If you are completely new to Chef, you might want to start with some
introductory material before delving into this.

Note that this document describes the _general_ cases. Everything said here has
exceptions and qualifiers.

## Brief Anatomy of a Chef Run

The full explanation of what happens during a Chef client run can be found
[here](https://github.com/jhotta/chef-fundamentals-ja/blob/master/slides/anatomy-of-a-chef-run/01_slide.md),
but the aim of this document is to elaborate on what happens specifically during
the compile-time and run-time phases.

We start with a *run_list*, which expands into a collection of _recipes_.
During the compile phase of a Chef run, the recipes are run in the order of the
*run_list* (or as they are included by `include_recipe` statements).  As the
recipes run, they result in a list of _resources_ - the Chef _resource
collection_.  When the last recipe has been run, the Chef client run moves onto
the run phase.  During the run-time phase, each of the resources is executed in
order of the _resource collection_.  Each resource is "converged" - the point
where Chef actually inspects the system state and enforces the configured state,
if they differ.

Take for example this toy recipe:  **fb_awesomesoft/recipes/default.rb**

```ruby
package 'awesomesoft' do
  action :upgrade
end

template '/etc/awesomesoft.conf' do
  source 'awesomesoft.conf.erb'
end

service 'awesomed' do
  action [:enable, :start]
end
```

At compile-time, this recipe evaluates into a list of resources:

| package awesomesoft | template awesomesoft.conf | service awesomed           |
| ------------------- | ------------------------- | -------------------------- |
| `action :upgrade`   | `action :default`         | `action [:enable, :start]` |

If this recipe was the full *run_list*, then after building this list of
resources, the Chef client would proceed from the compile-time into the
run-time, running the associated action against each resource in order.

It is sometimes useful to understand what actually happens under the hood here:
compile-time is actually building objects (a `Template` object or a `Package`
object, for example), and storing it along with a list of actions, on a list.
At run-time, it simple calls the `run_action` method on each object with the
list of corresponding actions.

## The Facebook Chef API

In the Facebook model, we build upon the Chef _node object_ to define
configuration data, and then implement that configuration by reading from the
same node object. This means that the order or critical; if the implementation
code reads the configured value _prior_ to the value being defined, the system
falls apart.

To make this work, we enforce the following pattern:
* _set_ values at compile-time
* _read_ them at run-time

Therefore, to use a cookbook's API, one sets the corresponding node attribute in
their recipe _at compile time_. This is denoted with `node.default` to specify
that this is a _writer_:

```ruby
node.default['fb_swap']['enabled'] = false
```

This attribute might be set in multiple different recipes, to different values.
This is okay, and by design; this follows the _last writer wins_ model, such
that whatever recipe set the attribute last will have that value be the one
that is actually implemented. Typically in the *run_list* a later recipe will
be more specific to the system, and therefore better suited to define the
desired state.

In this example, within the
[`fb_swap`](https://github.com/facebook/chef-cookbooks/tree/master/cookbooks/fb_swap)
cookbook, which actually implements this setting, the resources which read this
value are only allowed to do so _at run-time_.  This is denoted with just
`node`, to indicate this is a _reader_:

```ruby
# e.g. within a template erb (which is rendered at run-time)
enabled = <%= node['fb_swap']['enabled'] %>
```

## Is this node attribute part of an API?

These rules - to only _write_ to node attributes during compile time, and only
_read_ the same at run time, are only required for node attributes which make
up an API.

Many node attributes - like those build by Ohai, including information
populated via Ohai plugins - can be safely read from recipes at compile time.
They are not part of an API.

Cookbook APIs should define any node attributes which are part of their API
within said cookbook's README. All attributes defined by a cookbook must be
under its namespace (`node[<cookbook_name>]`) and treated like an API unless
specifically prefixed with an underscore to denote it is internal. Wherever
possible, non-API data should be put in local variables instead.

## Is this attribute being resolved at compile or run time?

You'll need to know whether an attribute will be evaluated at compile time or
run time.

You can assume attributes will be evaluated at compile time, except for the
following cases:

### Execute phase code blocks:

[comment]: # (Why an HTML table? Because GitHub doesn't support code blocks)
[comment]: # (in markdown tables)
<table>
  <tr>
    <th>Case</th>
    <th>Details</th>
    <th>Example</th>
  </tr>
  <tr>
    <td>ruby within a template</td>
    <td>
      `only_if`, `not_if`: specify a code block which will be resolved at run
      time
    </td>
    <td>
      in <tt>some_template.rb</tt>:<br>
<pre lang="ruby">
version = <%= node['some']['attribute'] %>
</pre>
    </td>
  </tr>
  <tr>
    <td>guards</td>
    <td>templates are rendered at runtime</td>
    <td>
<pre lang="ruby">
package 'some package' do
  only_if { node['something']['enabled'] }
end
</pre>
    </td>
  </tr>
  <tr>
    <td>lazy resource properties</td>
    <td>Specify a code block which will be resolved at run time</td>
    <td>
<pre lang="ruby">
package 'some package' do
  version lazy { node['some']['version'] }
end
</pre>
    </td>
  </tr>
  <tr>
    <td>provider actions</td>
    <td>
      The vast majority of configuration enforcement happens in providers,
      which run at run time.
    </td>
    <td>
<pre lang="ruby">
action :run do
  my_temp_var = node['something']['or_other']
  ...
end
</pre>
    </td>
  </tr>
  <tr>
    <td>ruby blocks</td>
    <td>An arbitrary block of ruby which will be run at run time.</td>
    <td>
<pre lang="ruby">
ruby_block 'some code' do
  block do
    my_temp_var = node['something']['someval'] }
  end
end
</pre>
    </td>
  </tr>
</table>

## An API Interaction Gone Wrong

Consider again `fb_awesomesoft`, this time with a new (but broken) feature - an
API to allow the version of the package to be specified. A second recipe sets
this value.  The *run_list* order is `fb_awesomesoft::default`,
`fb_someapp::default`.

We specify a default value for our attribute
`fb_awesomesoft/attributes/default.rb`:

```ruby
default['fb_awesomesoft'] = {
  'version' => 1,
}
```

We implement the new setting by specifying a `version` property on the package
resource in `fb_awesomesoft/recipes/default.rb`:

```ruby
...

# bad example, don't do this!
package 'awesomesoft' do
  version node['fb_awesomesoft']['version']
  action :install
end
```

And some app sets it in `fb_someapp/recipes/default.rb`:

```ruby
node.default['fb_awesomesoft']['version'] = 42
```

This doesn't work, because `version` in the package resource is evaluated _at
compile time_, such that it reads the value prior to all recipes having a
chance to set it.  As a result, the assembled resource collection specifies a
version of `1`, based on the default value:

| package awesomesoft | template awesomesoft.conf | service awesomed           |
| ------------------- | ------------------------- | -------------------------- |
| `action :upgrade`   | `action :default`         | `action [:enable, :start]` |
| `version 1`         |                           |                            |

When runtime begins, the version set by chef will not incorporate the value set
by `fb_someapp`.

## An API Interaction Done Right

To make the implementation work correctly, we need the implementing recipe to
read the attribute at run time.  In this case, we can postpone the resolution
of the version property using `lazy` in `fb_awesomesoft/recipes/default.rb`:

```ruby
...
package 'awesomesoft' do
  version lazy { node['fb_awesomesoft']['version'] }
  action :install
end
```

With a lazy property, the value saved into the resource collection is a proc,
which will be evaluated at run time.  The resource collection is thus:

| package awesomesoft                                  | template awesomesoft.conf | service awesomed           |
| ---------------------------------------------------- | ------------------------- | -------------------------- |
| `action :upgrade`                                    | `action :default`         | `action [:enable, :start]` |
| `version proc { node['fb_awesomesoft']['version'] }` |                           |                            |

When the package resource is converged at run-time, it will evaluate the node
attribute, and correctly set it to `42`.

## Other Examples

### harmful refactoring
Take this case:

```ruby
resource 'some_thing' do
  only_if { node['fb_awesomesoft']['enabled'] }
end

resource 'some_other_thing' do
  only_if { node['fb_awesomesoft']['enabled'] }
end
```

This code looks like it could be simplified into the following:

```ruby
# BAD - DON'T DO THIS
if node['fb_awesomesoft']['enabled'] {
  resource 'some_thing'
  resource 'some_other_thing'
}
```

This doesn't work, because the evaluation of
`if node['fb_awesomesoft']['enabled']` happens at compile time, and if some
recipe later in the run list were to change it, it would be too late; the
resource would not have been defined. In the original (correct) code:
`only_if { node['fb_awesomesoft']['enabled'] }` is a gate, which is evaluated
at run time, and is therefore API safe.

### Compound API interactions

If you have to read the contents of one API in order to write another API, you
can often achieve this by using a `whyrun_safe_ruby_block` which is prior to
the implementing resource. For example, to add an entry to the hash for each
[`fb_timers`](https://github.com/facebook/chef-cookbooks/tree/master/cookbooks/fb_timers)
job in an API-safe way, you can do:

```ruby
whyrun_safe_ruby_block 'set fb_timer XAR environments' do
  block do
    node['fb_timers']['jobs'].each_key do |name|
      node.default['fb_timers']['jobs'][name][
        'service_options']['Environment=XAR_MOUNT_SEED'] = name
    end
  end
end
```

Since this is a `ruby_block`, the read will happen at run time, and as long as
this resource is before the implementing resource (in this case the
`fb_timers_setup 'fb_timers system setup'` resource in `fb_timers`) this will
still be API-safe.

## Library Calls

Library calls are often confusing. The important thing to remember is that
library code is not inherently compile-time nor runtime - it's simply where you
call it. So, for example, in a recipe, this:

```ruby
# do not do this
package FB::Thingy.determine_packages(node) do
  action :upgrade
end
```

where `determine_packages` is selecting packages based on the API attributes
set in the node, is **not** runtime-safe. The exact same code inside of a
custom resource **would** be runtime-safe. Or doing the following in a recipe
instead would also be runtime-safe:

```ruby
package 'thingy packages' do
  package_name lazy { FB::Thingy.determine_packages(node) }
  action :upgrade
end
```

And, just to be clear, if a method never references the node, or anything in
the node (or only references Ohai data), then it is inherently safe to call any
time.
