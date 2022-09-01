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

def get_manifest(manifest_url, m = nil)
  puts_or_reply "ℹ Grabbing manifest from #{manifest_url.bold}…", m
  manifest = RestClient.get(manifest_url).read

  puts 'ℹ Parsing manifest JSON…'
  parsed = JSON.parse(manifest, symbolize_names: true)
  puts "ℹ Parsed manifest: #{parsed}"

  parsed
rescue StandardError
  nil
end

# This method uses puts because Bot.log might not be loaded from the Rakefile.
# rubocop: disable Style/OptionalBooleanParameter
def plugin_install(manifest, update_if_exists = true, m = nil)
  if !manifest
    puts_or_reply 'Bad manifest, aborting install', m
    puts "Manifest: #{manifest.inspect}"
    return
  end
  # rubocop: enable Style/OptionalBooleanParameter

  puts_or_reply "ℹ Installing plugin #{manifest[:name].bold.cyan}...", m

  repo = manifest[:git]
  plugin_name = manifest[:name]
  has_dependencies = manifest[:has_dependencies]
  puts "ℹ Git repo is at #{repo}"

  FileUtils.mkdir_p(EXTERNAL_PLUGINS_DIR)
  plugin_path = File.join(EXTERNAL_PLUGINS_DIR, plugin_name)

  if File.directory?(plugin_path)
    puts_or_reply "ℹ #{plugin_name.bold.cyan} already exists! Updating it instead…", m

    return false if !update_if_exists

    plugin_update(plugin_name, 'master', m)
  else
    puts 'ℹ Cloning plugin…'
    Git.clone(repo, plugin_name, path: EXTERNAL_PLUGINS_DIR)

    puts_or_reply "🎉 Plugin #{plugin_name.bold.cyan} installed.", m

    if has_dependencies
      puts_or_reply 'This plugin requires external dependencies. Running `bundle install`...', m
      `bundle install`
    end

    true
  end
rescue StandardError => e
  puts_or_reply "🔥 Failed to install plugin: #{e}", m
  puts e.backtrace
  false
end

def plugin_update(name, branch = 'master', m = nil)
  plugin_path = File.join(EXTERNAL_PLUGINS_DIR, name)
  manifest_path = File.join(plugin_path, 'manifest.json')
  gemfile_path = File.join(plugin_path, 'Gemfile')

  puts_or_reply "ℹ Updating plugin #{name.bold.cyan}…", m

  g = Git.open(plugin_path)
  g.branch(branch).checkout
  current_sha = g.object('HEAD^1').sha.dup
  current_gemfile = File.file?(gemfile_path) ? File.read(gemfile_path) : nil
  puts_or_reply "ℹ Local SHA #{current_sha.cyan}", m

  g.pull
  new_sha = g.object('HEAD^1').sha
  new_date = g.object('HEAD^1').date
  new_gemfile = File.file?(gemfile_path) ? File.read(gemfile_path) : nil
  puts_or_reply "ℹ Remote SHA #{current_sha.cyan}", m

  updated = new_sha != current_sha
  has_dependencies = JSON.parse(File.read(manifest_path), symbolize_names: true)
  updated_gemfile = new_gemfile != current_gemfile

  action = updated ? 'updated to' : 'already at'
  puts_or_reply "🎉 Plugin #{name.bold.cyan} #{action} #{new_sha[0..7]} <#{new_date}> (#{branch}).", m

  if has_dependencies && updated_gemfile
    puts_or_reply "🎉 Plugin's Gemfile has changed. Running `bundle install`...", m
    `bundle install`
  end

  updated
rescue StandardError => e
  puts_or_reply "🔥 Failed to update plugin: #{e}", m
  puts e.backtrace
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
  puts e.backtrace
  false
end
