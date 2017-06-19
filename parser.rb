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
        page = link_t.click
        @semaphore.release
        @processed_products << parse_product(page)
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

  def not_found?(page)
    page = Nokogiri::HTML(page.body)
    if page.xpath("//div[@class=clearfix]//h1").text == "Page Not Found"
      true
    else
      false
    end
  end

  def parse_product(page)
    html = Nokogiri::HTML(page.body)
    multiproduct?(html) ? parse_multiproduct(html) : parse_regular_product(html)
  end

  def multiproduct?(html)
    !html.xpath('//div[@class="attribute_list"]').empty?
  end

  def parse_regular_product(html)
    image = get_image(html)
    name = get_name(html)
    puts image + " --- " + name
  end

  def parse_multiproduct(html)
    image = get_image(html)
    name = get_name(html)
    puts image + " --- " + name
  end

  def get_image(html)
    html.xpath('//img[@id="bigpic"]/@src').text
  end

  def get_name(html)
    html.xpath('//h1[@itemprop="name"]').text
  end

  def extract_multiproduct_data(html_mechanize)
    html_page = Nokogiri::HTML(html_mechanize.body)
    name = html_page.xpath('//h1[@id="product_family_heading"]').text
    products = html_page.xpath('//div[@class="title"]')
    products.each_with_index do |product, index|
      Console.fetching_product(index + 1)
      puts compose_product(html_page, name, products, index)
      @processed_products << compose_product(html_page, name, products, index)
    end
  end

  def compose_product(html_page, name, products, index)
    {
      :name => name + ' ' + get_name_weight(products[index]),
      :price => get_price(products, index),
      :image => get_image(html_page, products, index),
      :delivery_time => get_delivery_time(products, index),
      :product_code => get_product_code(products, index)
    }
  end

  def get_name_weight(product)
    product.text.gsub("\n", '').gsub("\t", '')
  end

  def get_price(products, index)
    products.xpath('//span[@itemprop="price"]')[index].text
  end

  def get_delivery_time(products, index)
    if !products.xpath('//strong[@class="stock in-stock"]')[index].nil?
      products.xpath('//strong[@class="stock in-stock"]')[index].text.gsub("\t", '').gsub("\n", '').strip!
    elsif !products.xpath('//strong[@class="stock out-stock"]')[index].nil?
      products.xpath('//strong[@class="stock out-stock"]')[index].text.gsub("\t", '').gsub("\n", '').strip!
    else
      'undefined'
    end
  end

  def get_product_code(products, index)
    products.xpath('//strong[@itemprop="sku"]')[index].text
  end

end
