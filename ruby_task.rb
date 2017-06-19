#!/usr/bin/env ruby

require './console.rb'
require './parser.rb'
require './file_manager.rb'

console = Console.new
parser = Parser.new(console.url)
parser.parse
