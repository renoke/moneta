begin
  require "fileutils"
  require "xattr"
rescue LoadError
  puts "You need the xattr gem to use the File moneta store"
  exit
end

module Moneta
  class File
    class Expiration
      def initialize(directory)
        @directory = directory
      end
      
      def [](key)
        attrs = xattr(key)
        ret = Marshal.load(attrs.get("moneta_expires"))
      rescue Errno::ENOENT, SystemCallError
      end
      
      def []=(key, value)
        attrs = xattr(key)
        attrs.set("moneta_expires", Marshal.dump(value))
      end
      
      def delete(key)
        attrs = xattr(key)
        attrs.remove("moneta_expires")
      end

      private
      def xattr(key)
        ::Xattr.new(::File.join(@directory, key))
      end
    end
    
    def initialize(options = {})
      @directory = options[:path]
      if ::File.file?(@directory)
        raise StandardError, "The path you supplied #{@directory} is a file"
      elsif !::File.exists?(@directory)
        FileUtils.mkdir(@directory)
      end
      
      @expiration = Expiration.new(@directory)
    end
    
    module Implementation
      def key?(key)
        ::File.exist?(path(key))
      end
      
      def has_key?(key)
        ::File.exist?(path(key))
      end
      
      def [](key)
        if ::File.exist?(path(key))
          Marshal.load(::File.read(path(key)))
        end
      end
      
      def []=(key, value)
        ::File.open(path(key), "w") do |file|
          contents = Marshal.dump(value)
          file.puts(contents)
        end
      end
      
      def fetch(key, default)
        self[key] || default
      end
      
      def delete(key)
        value = self[key]
        FileUtils.rm(path(key))
        value
      rescue Errno::ENOENT
      end
      
      def store(key, value, options = {})
        self[key] = value
      end
      
      def clear
        FileUtils.rm_rf(@directory)
        FileUtils.mkdir(@directory)
      end
      
      private
      def path(key)
        ::File.join(@directory, key)
      end
    end
    include Implementation
    include Expires
    
  end
end