class Bot::Plugin::Image < Bot::Plugin
  require 'digest/md5'
  require 'digest/sha2'
  require 'uri'
  require 'open-uri'
  require 'fileutils'

  def initialize(bot)
    @s = {
      trigger: { image: [:call, 0, 'Images the bot.'] },
      subscribe: true,
      filters: ['http.*png', 'http.*gif', 'http.*jpg', 'http.*jpeg', 'http.*bmp'],
      relative_database_path: ['lib', 'databases', 'images.sqlite3'],
      image_directory: ['lib', 'public', 'i']
    }
    super(bot)

    @db = Bot::Database.new(File.join(@s[:relative_database_path]))

    if !@db.table_exists?(:images)
      @db.create_table :images do
        primary_key :id
        String      :sha256, size: 64
        String      :md5
        String      :path
        String      :google_description
        Integer     :bytesize
      end
    end

    if !@db.table_exists?(:sources)
      @db.create_table :sources do
        primary_key :id
        foreign_key :image_id, :images, key: :id
        DateTime    :timestamp
        String      :url
        String      :source_name
        String      :context
        String      :filename
      end
    end
  end

  def call(m=nil)
    m.reply 'Random image will be implemented when the web interface is up.'
  end

  def receive(m)
    # Record each URL found in m.text
    line = String.new(m.text)

    @s[:filters].each do |regex|
      results = line.scan(Regexp.new(regex))

      results.each do |result|
        Bot.log.info "#{self.class.name} - Image detected: #{result}"
        record(result, m)
        line.gsub!(result, '') # Prevent double-matching
      end
    end
  end

  def record(url, m)
    Thread.new do
      temp_dir = File.join(*@s[:image_directory], 'temp')
      if !File.directory?(temp_dir)
        FileUtils.mkdir_p(temp_dir)
        File.write(File.join(temp_dir, '.gitignore'), "*\n!.gitignore")
        File.write(File.join(*@s[:image_directory], '.gitignore'), "*\n!.gitignore")
      end
      temp_path = File.join(temp_dir, "temp_#{Time.now.to_f}")

      # Grab file. TODO: setup a timeout
      File.open(temp_path, 'wb') do |f|
        f.write(open(url).read)
      end

      # Discard bad file
      File.delete(temp_path) if File.size?(temp_path).nil?

      # Record image if new
      sha256 = Digest::SHA256.file(temp_path).to_s

      if (matched_image = @db[:images].where(sha256: sha256)).to_a.empty?
        # New image
        filetype = File.extname(URI.parse(url).path)
        image_path = File.join(*@s[:image_directory], "#{sha256}.#{filetype}")
        FileUtils.mv(temp_path, image_path) if !File.file?(image_path)
        @db.from(:images).insert(
          sha256:             sha256,
          md5:                Digest::MD5.file(image_path).to_s,
          path:               image_path,
          google_description: 'not implemented',
          bytesize:           File.size(image_path)
        )
      else
        # Duplicate
        Bot.log.info "#{self.class.name} - This image is a duplicate."
        File.delete(temp_path)
      end

      # Record source
      @db.from(:sources).insert(
        image_id:    matched_image.to_a.first[:id],
        timestamp:   Time.now,
        url:         url,
        source_name: m.sender,
        context:     m.text,
        filename:    File.basename(URI.parse(url).path)
      )

      Bot.log.info "#{self.class.name} - #{url} saved."
    end
  end
end