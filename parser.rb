require 'nokogiri'
require 'mechanize'
require './console.rb'
require 'thread_safe'
require 'concurrent'

class Parser

  def initialize(url)
    @main_url  = url
    @agent = Mechanize.new
    @product_links = Array.new
    @multiproduct_count = 0
    @mutex = Mutex.new
    @processed_products = ThreadSafe::Array.new
    @semaphore = Concurrent::Semaphore.new(3)
  end


  def parse
    fetch_product_links
    current_page = 0
    threads = []
    for link in @product_links
      threads << Thread.new(link) do |link_t|
        @mutex.synchronize do
          Console.fetching_page(current_page += 1)
        end
        @semaphore.acquire
        sleep(0.5)
        page = link_t.click
        @semaphore.release
        @processed_products += parse_product(page)
      end
    end

    threads.each {|thr| thr.join }
    Console.done(@processed_products.size)
    @processed_products
  end

  def fetch_product_links
    main_page = @agent.get(@main_url)
    form = main_page.form_with(:class => 'showall pull-left')
    button = form.buttons[0]
    @agent.submit(form, button)
    products_page = @agent.page
    products_page.links.each do |link|
      cls = link.attributes.attributes['class']
      @product_links << link if cls && cls.value == 'product-name'
    end
  end

  def parse_product(page)
    html = Nokogiri::HTML(page.body)
    products_array = Array.new
    image = get_image(html)
    name = get_name(html)
    prices = get_prices(html)
    prices.each do |opt|
    products_array << {
        'name' => name.concat(' ').concat(opt['weight']),
        'price' => opt['price'],
        'image' => image
      }
    end
    puts products_array
    products_array
  end

  def get_image(html)
    html.xpath('//img[@id="bigpic"]/@src').text
  end

  def get_name(html)
    html.xpath('//h1[@itemprop="name"]').text.gsub("\n", "").strip.gsub("\t", " ")
  end

  def get_prices(html)
    options = html.xpath('//ul[@class="attribute_labels_lists"]//li')
    prices = Array.new
    options.each_with_index do |option, index|
      prices << extract_price_hash(option, index)
    end
    prices
  end

  def extract_price_hash(option, index)
    spans = option.xpath('//ul[@class="attribute_labels_lists"]//li//span')
    weight = spans[index*4].text
    price = spans[index*4 + 1].text.gsub("\n", "").strip
    {
      'weight' => weight,
      'price' => price
    }
  end

end
