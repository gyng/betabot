task :add_account do
  require 'io/console'
  require 'json'
  require 'securerandom'
  require 'base64'

  require_relative('./lib/bot/core')
  require_relative('./lib/bot/core/authenticator')

  path = File.join('lib', 'settings')
  authenticator = Bot::Core::Authenticator.new(path)

  puts 'Enter account name:'
  account_name = STDIN.gets.chomp
  puts 'Enter authentication level (number 1-5, 5 being highest):'
  auth_level = STDIN.gets.chomp.to_i
  puts 'Enter password:'
  password = STDIN.noecho(&:gets).chomp
  puts 'Enter password again:'
  password_confirmation = STDIN.noecho(&:gets).chomp

  if password != password_confirmation
    puts 'Password does not match confirmation, try again.'
  else
    authenticator.make_account(account_name, auth_level, password)
    puts "Account #{account_name} created."
  end
end

# Run with `rake make_plugin[name]`
task :make_plugin, :name do |t, args|
  require 'fileutils'

  name = args[:name]

  dir = File.join('lib', 'plugins', name)
  FileUtils.mkdir_p(dir)
  template = File.join('lib', 'plugins', 'ping', 'ping.rb')
  plugin = File.join(dir, name + '.rb')
  FileUtils.cp(template, plugin)

  to_edit = File.read(plugin)
  name_sentence_case = name[0].upcase + name[1..-1]
  to_edit.gsub!('Ping', name_sentence_case)
  to_edit.gsub!('ping', name.downcase)

  File.write(plugin, to_edit)

  FileUtils.mkdir_p(File.join(dir, 'settings'))
  File.write(File.join(dir, 'settings', '.gitignore'), 'settings.json')
end

task :package_plugin, :name do |t, args|
  require 'zip'
  require 'fileutils'
  require 'digest/sha1'

  packages_dir = 'packages'
  name = args[:name]

  FileUtils.mkdir_p(packages_dir)
  dir = File.join('lib', 'plugins', name)
  sha = Digest::SHA1.hexdigest(File.read(File.join(dir, "#{name}.rb")))[0..7]
  out = File.join(packages_dir, "#{name}.#{sha}.plugin.zip")

  Zip::File.open(out, Zip::File::CREATE) do |zipfile|
    Dir[File.join(dir, '**', '**')].each do |file|
      zipfile.add(file.sub(dir + File::SEPARATOR, ''), file)
    end
  end
  puts "Package created in #{out}."
end

task :install_plugin, :url do |t, args|
  require 'zip'
  require 'fileutils'
  require 'openssl'
  require 'open-uri'
  require 'uri'

  url = args[:url]
  packages_dir = 'packages'
  FileUtils.mkdir_p(packages_dir)

  package_name = File.basename(URI.parse(url).path)
  package_path = File.join(packages_dir, package_name)

  puts "Downloading package from #{url}"
  open(url, { ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE }) do |f|
    File.open(package_path, "wb") do |file|
      file.puts f.read
    end
  end

  puts "Package downloaded. Extracting..."
  plugin_name = package_name.match(/(?<name>.+?)\..+/)[:name]
  plugin_dir = File.join('lib', 'plugins', plugin_name)
  FileUtils.mkdir_p(plugin_dir)

  Zip::File.open(package_path) do |zip_file|
    zip_file.each do |f|
      f_path = File.join(plugin_dir, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path) unless File.exist?(f_path)
    end
  end

  puts "Cleaning up downloaded files..."
  File.delete(package_path)

  puts "\nPlugin #{plugin_name} installed to #{plugin_dir}!\n" +
       "Run `bundle install` to install plugin dependencies."
end