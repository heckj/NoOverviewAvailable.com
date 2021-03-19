# frozen_string_literal: true

require 'open-uri'
require 'fileutils'
require 'net/http'

require 'parallel'
require 'kimurai'
# Kimurai docs: <https://rubydoc.info/gems/kimurai/1.0.1>
require 'nokogiri'
require 'mechanize'
require 'odyssey'

class AppleDeveloperSpider < Kimurai::Base
  @engine = :mechanize
  @start_urls = ['https://developer.apple.com/documentation/technologies/']
  @config = {
    skip_duplicate_requests: true,
    retry_request_errors: [Net::HTTPNotFound]
  }

  # With the updated Rake task, each parse starts at a top-level framework page,
  # with a starting URL for each technology.

  # def parse(response, url:, data: {})
  #   Parallel.each(response.css('a.category-list-item-link')) do |framework|
  #     request_to :parse_framework, url: URI.join('https://developer.apple.com/', framework[:href]).to_s
  #   rescue StandardError => e
  #     puts "There is failed request (#{e.inspect}), skipping it..."
  #   end
  # end

  def parse(response, url:, data: {})
    framework_path = URI.parse(url).path

    # response is Nokogiri::HTML::Document
    # documentation: https://nokogiri.org/rdoc/Nokogiri/HTML/Document.html
    
    # example pages this should handle:
    # - https://developer.apple.com/documentation/accessibility
    # - https://developer.apple.com/documentation/app_clips
    # - https://developer.apple.com/documentation/foundation

    puts "=== PRINTF-DEBUG ==="
    checking = response.search('.topictitle')
    # helpful interactive development/debugging using Nokogiri to extract data
    # from HTML: <http://ruby.bastardsbook.com/chapters/html-parsing/>

#     require 'rubygems'
# require 'nokogiri'
# require 'open-uri'
   
# page = Nokogiri::HTML(open("http://en.wikipedia.org/"))   
# puts page.class   # => Nokogiri::HTML::Document


    # the CSS tags have all evolved since this was created
    type = begin
      response.search('.topictitle .eyebrow')[0].text.strip
    rescue StandardError
      nil
    end
    print("Identified type of page: ", type, "\n")
    return unless type == 'Framework' || type.nil?

    response.css('a.symbol-name').each do |symbol|
      next unless symbol[:href].start_with?(framework_path)

      begin
        request_to :parse_symbol, url: URI.join('https://developer.apple.com/', symbol[:href]).to_s, data: { framework_path: framework_path }
      rescue StandardError => e
        puts "There is failed request (#{e.inspect}), skipping it..."
      end
    end
  end

  def parse_symbol(response, url:, data: {})
    framework_path = data[:framework_path]

    symbol = {}
    symbol[:type] = begin
      ## .topictitle .eyebrow
                      response.search('.topic-title .eyebrow')[0].text.strip
                    rescue StandardError
                      nil
                    end
    if symbol[:type]
      symbol[:url] = url
      ## .topictitle .title
      symbol[:name] = response.search('.topic-heading')[0].text.strip
      breadcrumbs_selector = %w[a span].map { |element| ".localnav-menu-breadcrumbs li #{element}" }.join(', ')
      symbol[:breadcrumbs] = response.search(breadcrumbs_selector).map { |e| e.text.strip.gsub(/⋯/, '') }
      symbol[:framework] = response.search('.frameworks li:first').text
      
      # nodocumentation is still the CSS used for "No overview available."
      symbol[:is_documented] = response.at('.nodocumentation').nil?

      text = response.search('#topic-content, .topic-description').text
      statistics = Odyssey.flesch_kincaid_re(text, true)

      symbol[:number_of_words] = statistics['word_count']
      symbol[:number_of_sentences] = statistics['sentence_count']
      symbol[:flesch_kincaid_readability] = statistics['score']
      headings_selector = (1...6).map { |level| "#topic-content h#{level}" }.join(', ')
      symbol[:number_of_headings] = response.search(headings_selector).count
      symbol[:number_of_diagrams] = response.search('#topic-content figure img').count
      symbol[:number_of_code_listings] = response.search('#topic-content figure code').count
      symbol[:number_of_topics] = response.search('#topics section').count

      sdks = {}
      # .summary-list-item.platform li
      response.search('.sdks li').each do |sdk|
        *platform, version = sdk.text.split
        sdks[platform.join(' ')] = version
      end
      symbol[:sdks] = sdks

      framework_name = framework_path.split(%r{/}).last

      path = symbol[:url].sub('https://developer.apple.com/documentation/', '')
      filepath = File.join('tmp', path) + '.json'
      FileUtils.mkdir_p(File.dirname(filepath))
      File.write(filepath, Oj.dump(symbol, mode: :compat))
    end

    response.css('a.symbol-name').each do |symbol|
      next if framework_path && !symbol[:href].start_with?(framework_path)

      begin
        request_to :parse_symbol, url: URI.join('https://developer.apple.com/', symbol[:href]).to_s, data: data
      rescue StandardError => e
        puts "There is failed request (#{e.inspect}), skipping it..."
      end
    end
  end
  end
