# Chefctl - A Pluggable Chef Controller

## Intro

Chefctl is an extensible script for managing Chef runs in a consistent and
reliable way on a variety of platforms. It takes care of managing log files,
reaps old Chef processes and uses a lock to ensure only a single instance
of Chef is running at a given time.

## Features

- System-level lock file
- Clean up old Chef processes
- Log file management
- Hook API for custom extensions (see below)
- Platform agnostic, tested to work on Linux, OSX and Windows

## Requirements

`chefctl.rb` does not bootstrap Chef (though you could do that with a plugin
if you wanted), and expects the system to use Omnibus Chef (as it relies on the
embedded ruby it provides). If you're not using Omnibus you'll want to run
`chefctl.rb` via your own Ruby interpreter, or change its shebang to point to
it.

## Customizing Behavior with Hooks

Chefctl has a plugin model that allows you to override or customize its
behavior to suit your use-case.

See `chefctl_hooks.rb` for a sample hook file, and description of each of the
available hooks.

See `sample_hooks/` for a few sample hooks for common use-cases.

## Getting started

`chefctl.rb` is the main Chef controller script you'll want to deploy on your
machines; `chefctl_hooks.rb` and `chefctl-config.rb` are empty hook and config
files for it. If you're using systemd, we also provide unit files that can be
used to run Chef via `chefctl.rb` under `systemd/`.

## When Hooks are Called

The high-level behavior of chefctl.rb is as follows:

- Call the `cli_options` hook
- Parse command-line options\*
- Call the `pre_start` hook
- Acquire the lock
- Call the `pre_run` hook
- Run Chef
- Call `rerun_chef?` unless we've hit `Chefctl::Config.max_retries`
- Rerun chef if necessary
- Call the `post_run` hook
- Release the lock

\*: Parsing command-line options is a bit more complex than this, since the
hook file location can be provided as a command-line option, but this sufficient
for a high-level overview.
