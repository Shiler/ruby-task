require 'slop'
require 'colorize'

class Console

  attr_accessor :url, :filename

  def initialize
    get_parameters
  end

  def get_parameters
    opts = Slop.parse suppress_errors: true do |o|
      o.string '...'
      o.string '...', default: 'data'
    end
    check_parameters(opts.arguments)
    @url = opts.arguments.first
    @filename = opts.arguments.last.gsub('.csv', '')
  end

  def banner
    puts 'Invalid arguments. Usage: '.colorize(:red)
    puts "\t./task_ruby_1.rb 'URL' 'FILENAME'".colorize(:green)
  end

  def uri?(string)
    url = URI.encode(string)
    uri = URI.parse(url)
    %w( http https ).include?(uri.scheme)
  rescue URI::BadURIError
    false
  rescue URI::InvalidURIError
    false
  end

  def check_parameters(args)
    if args.size != 2
      Console.banner
      exit
    end
    unless uri?(args.first)
      Console.banner
      exit
    end
  end

  def Console.fetching_page(index)
    puts "Fetching page: #{index}".colorize(:blue)
  end

  def Console.fetching_multiproduct(index)
    puts "  Fetching multiproduct: #{index}".colorize(:yellow)
  end

  def Console.fetching_product(index)
    puts "    Fetching product: #{index}".colorize(:green)
  end

  def Console.done(count)
    puts "Done.\nTotal: #{count} products".colorize(:red)
  end

  def Console.file_saved(name)
    puts "File '#{name}.csv' saved.".colorize(:blue)
  end

end
