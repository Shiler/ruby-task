require 'csv'
require './console.rb'

class FileManager
  def FileManager.save(hashes, filename)
    CSV.open("#{filename}.csv", "w", headers: hashes.first.keys) do |csv|
      hashes.each do |h|
        csv << h.values
      end
    end
    Console.file_saved(filename)
  end
end
