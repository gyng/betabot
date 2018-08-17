require 'git'
require 'json'
require 'open-uri'

EXTERNAL_PLUGINS_DIR = 'lib/external_plugins'.freeze

def puts_or_reply(msg, m)
  if m.nil?
    puts msg
  else
    m.reply msg
  end
end

# This method uses puts because Bot.log might not be loaded from the Rakefile.
def plugin_install(manifest_url, m = nil)
  puts_or_reply "ℹ Grabbing manifest from #{manifest_url.bold}…", m
  manifest = open(manifest_url).read

  puts 'ℹ Parsing manifest JSON…'
  parsed = JSON.parse(manifest, symbolize_names: true)
  puts "ℹ Parsed manifest: #{parsed}"

  repo = parsed[:git]
  plugin_name = parsed[:name]
  has_dependencies = parsed[:has_dependencies]
  puts "ℹ Git repo is at #{repo}"

  FileUtils.mkdir_p(EXTERNAL_PLUGINS_DIR)
  plugin_path = File.join(EXTERNAL_PLUGINS_DIR, plugin_name)

  if File.directory?(plugin_path)
    puts_or_reply "ℹ #{plugin_name.bold.cyan} already exists! Updating it instead…", m
    updated = plugin_update(plugin_name, 'master', m)
    return updated
  else
    puts 'ℹ Cloning plugin…'
    Git.clone(repo, plugin_name, path: EXTERNAL_PLUGINS_DIR)

    puts_or_reply "🎉 Plugin #{plugin_name.bold.cyan} installed.", m
    puts_or_reply 'This plugin requires external dependencies. Run `bundle install` and restart.', m if has_dependencies
    return true
  end
rescue StandardError => e
  puts_or_reply "🔥 Failed to install plugin: #{e}", m
  false
end

def plugin_update(name, branch = 'master', m = nil)
  plugin_path = File.join(EXTERNAL_PLUGINS_DIR, name)
  puts_or_reply "ℹ Updating plugin #{name.bold.cyan}…", m

  g = Git.open(plugin_path)
  g.branch(branch).checkout
  current_sha = g.object('HEAD^1').sha.dup

  g.pull
  new_sha = g.object('HEAD^1').sha
  new_date = g.object('HEAD^1').date
  updated = new_sha != current_sha

  action = updated ? 'updated to' : 'already at'
  puts_or_reply "🎉 Plugin #{name.bold.cyan} #{action} #{new_sha[0..7]} <#{new_date}> (#{branch}).", m

  updated
rescue StandardError => e
  puts_or_reply "🔥 Failed to update plugin: #{e}", m
  false
end

def plugin_remove(name, m = nil)
  require 'fileutils'

  plugin_path = File.join(EXTERNAL_PLUGINS_DIR, name)
  puts_or_reply "ℹ Removing plugin #{name.bold.cyan}…", m

  FileUtils.rm_rf(plugin_path)

  puts_or_reply "🎉 Plugin #{name.bold.cyan} removed.", m
  true
rescue StandardError => e
  puts_or_reply "🔥 Failed to remove plugin: #{e}", m
  false
end
