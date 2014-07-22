#!/opt/chef/embedded/bin/ruby
# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2

require_relative '../between-meals/util'
require_relative '../between-meals/knife'
require_relative '../between-meals/repo/svn'
require_relative '../between-meals/repo/git'
require_relative '../between-meals/changeset'
require_relative 'grocery-delivery/config'
require_relative 'grocery-delivery/logging'
require_relative 'grocery-delivery/hooks'
require 'optparse'

# rubocop:disable GlobalVars
$success = false
$status_msg = 'NO WORK DONE'
$lockfileh = nil

def action(msg)
  if GroceryDelivery::Config.dry_run
    GroceryDelivery::Log.warn("[DRYRUN] Would do: #{msg}")
  else
    GroceryDelivery::Log.warn(msg)
  end
end

def get_lock
  GroceryDelivery::Log.warn('Attempting to acquire lock')
  $lockfileh = File.open(GroceryDelivery::Config.lockfile,
                         File::RDWR | File::CREAT, 0600)
  $lockfileh.flock(File::LOCK_EX)
  GroceryDelivery::Log.warn('Lock acquired')
end

def write_pidfile
  File.write(GroceryDelivery::Config.pidfile, Process.pid)
end

def checkpoint_path
  File.join(GroceryDelivery::Config.master_path,
            GroceryDelivery::Config.rev_checkpoint)
end

def write_checkpoint(rev)
  File.write(checkpoint_path, rev) unless GroceryDelivery::Config.dry_run
end

def read_checkpoint
  GroceryDelivery::Log.debug("Reading #{checkpoint_path}")
  File.exists?(checkpoint_path) ? File.read(checkpoint_path).strip : nil
end

def full_upload(knife)
  GroceryDelivery::Log.warn('Uploading all cookbooks')
  knife.cookbook_upload_all
  GroceryDelivery::Log.warn('Uploading all roles')
  knife.role_upload_all
  GroceryDelivery::Log.warn('Uploading all databags')
  knife.databag_upload_all
end

def partial_upload(knife, repo, checkpoint, local_head)
  GroceryDelivery::Log.warn(
    "Determing changes... from #{checkpoint} to #{local_head}"
  )
  changeset = BetweenMeals::Changeset.new(
    GroceryDelivery::Log,
    repo,
    checkpoint,
    local_head,
    {
      :cookbook_dirs =>
        GroceryDelivery::Config.cookbook_paths,
      :role_dir =>
        GroceryDelivery::Config.role_path,
      :databag_dir =>
        GroceryDelivery::Config.databag_path,
    },
  )
  deleted_cookbooks = changeset.cookbooks.select { |x| x.status == :deleted }
  added_cookbooks = changeset.cookbooks.select { |x| x.status == :modified }
  deleted_roles = changeset.roles.select { |x| x.status == :deleted }
  added_roles = changeset.roles.select { |x| x.status == :modified }
  deleted_databags = changeset.databags.select { |x| x.status == :deleted }
  added_databags = changeset.databags.select { |x| x.status == :modified }

  {
    'Added cookbooks' => added_cookbooks,
    'Deleted cookbooks' => deleted_cookbooks,
    'Added roles' => added_roles,
    'Deleted roles' => deleted_roles,
    'Added databags' => added_databags,
    'Deleted databags' => deleted_databags,
  }.each do |msg, list|
    if list
      GroceryDelivery::Log.warn("#{msg}: #{list}")
    end
  end

  knife.cookbook_delete(deleted_cookbooks) if deleted_cookbooks
  knife.cookbook_upload(added_cookbooks) if added_cookbooks
  knife.role_delete(deleted_roles) if deleted_roles
  knife.role_upload(added_roles) if added_roles
  knife.databag_delete(deleted_databags) if deleted_databags
  knife.databag_upload(added_databags) if added_databags
end

def upload_changed(repo, checkpoint)
  local_head = repo.head
  base_dir = File.join(GroceryDelivery::Config.master_path,
                       GroceryDelivery::Config.reponame)

  knife = BetweenMeals::Knife.new(
    {
      :logger => GroceryDelivery::Log,
      :config => GroceryDelivery::Config.knife_config,
      :bin => GroceryDelivery::Config.knife_bin,
      :role_dir => File.join(base_dir, GroceryDelivery::Config.role_path),
      :cookbook_dirs => GroceryDelivery::Config.cookbook_paths.map do |x|
        File.join(base_dir, x)
      end,
      :databag_dir => File.join(base_dir, GroceryDelivery::Config.databag_path),
    }
  )

  if checkpoint
    partial_upload(knife, repo, checkpoint, local_head)
  else
    full_upload(knife)
  end
  return local_head
end

def setup_config
  options = {}
  OptionParser.new do |opts|
    options[:config_file] = GroceryDelivery::Config.config_file
    opts.on('-n', '--dry-run', 'Dryrun mode') do |s|
      options[:dry_run] = s
    end
    opts.on('-d', '--debug', 'Debug mode') do |s|
      options[:debug] = s
    end
    opts.on('-T', '--timestamp', 'Timestamp output') do |s|
      options[:timestamp] = s
    end
    opts.on('-c', '--config-file FILE', 'config file') do |s|
      unless File.exists?(File.expand_path(s))
        logger.error("Config file #{s} not found.")
        exit 2
      end
      options[:config_file] = s
    end
    opts.on('-l', '--lockfile FILE', 'lockfile') do |s|
      options[:lockfile] = s
    end
    opts.on('-p', '--pidfile FILE', 'pidfile') do |s|
      options[:pidfile] = s
    end
  end.parse!
  if File.exists?(File.expand_path(options[:config_file]))
    GroceryDelivery::Config.from_file(options[:config_file])
  end
  GroceryDelivery::Config.merge!(options)
  GroceryDelivery::Log.debug = GroceryDelivery::Config.debug
  if GroceryDelivery::Config.dry_run
    GroceryDelivery::Log.warn('Dryrun mode activated, no changes will be made.')
  end
  GroceryDelivery::Hooks.get(GroceryDelivery::Config.plugin_path)
  at_exit do
    GroceryDelivery::Hooks.atexit(GroceryDelivery::Config.dry_run,
                                  $success, $status_msg)
  end
end

def get_repo
  repo_path = File.join(GroceryDelivery::Config.master_path,
                        GroceryDelivery::Config.reponame)
  r = BetweenMeals::Repo.get(GroceryDelivery::Config.vcs_type, repo_path,
                             GroceryDelivery::Log)
  if GroceryDelivery::Config.vcs_path
    r.bin = GroceryDelivery::Config.vcs_path
  end
  r
end

setup_config

GroceryDelivery::Hooks.preflight_checks(GroceryDelivery::Config.dry_run)

get_lock
write_pidfile
repo = get_repo

GroceryDelivery::Hooks.prerun(GroceryDelivery::Config.dry_run)

if repo.exists?
  action('Updating repo')
  repo.update unless GroceryDelivery::Config.dry_run
else
  unless GroceryDelivery::Config.repo_url
    logger.error('No repo URL was specified, and no repo is checked out')
    exit(1)
  end
  action('Cloning repo')
  unless GroceryDelivery::Config.dry_run
    repo.checkout(GroceryDelivery::Config.repo_url)
  end
end

GroceryDelivery::Hooks.post_repo_up(GroceryDelivery::Config.dry_run)

if GroceryDelivery::Config.dry_run && !repo.exists?
  GroceryDelivery::Log.warn(
    'In dryrun mode, with no repo, there\'s not much I can dryrun'
  )
  GroceryDelivery::Hooks.postrun(GroceryDelivery::Config.dry_run, true,
                                 'dryrun mode')
  exit
end

checkpoint = read_checkpoint
if repo.exists? && repo.head == checkpoint
  GroceryDelivery::Log.warn('Repo has not changed, nothing to do...')
  $success = true
  $status_msg = "Success at #{checkpoint}"
else
  begin
    ver = upload_changed(repo, checkpoint)
    write_checkpoint(ver)
    $success = true
    $status_msg = "Success at #{ver}"
  rescue => e
    $status_msg = e.message
    e.backtrace.each do |line|
      GroceryDelivery::Log.error(line)
    end
  end
end

GroceryDelivery::Log.warn($status_msg)
GroceryDelivery::Hooks.postrun(GroceryDelivery::Config.dry_run, $success,
                               $status_msg)
# rubocop:enable GlobalVars
