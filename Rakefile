# frozen_string_literal: true

require './lib/apple_developer_spider'

require 'rake/clean'

require 'oj'
require 'parallel'

require 'net/http'
require 'json'

directory 'tmp'
CLEAN << 'tmp'

directory '_data/frameworks'
CLOBBER << '_data/frameworks'

task scrape: ['tmp'] do

  # top level page no longer includes direct links to underlying HTML, instead
  # it's updated with Javascript that loads in the technologies from a JSON
  # manifest, published at 
  # https://developer.apple.com/tutorials/data/documentation/technologies.json
  spider = AppleDeveloperSpider

  baseURI="https://developer.apple.com"
  uri = URI('https://developer.apple.com/tutorials/data/documentation/technologies.json')
  response = Net::HTTP.get(uri)
  print('Technologies JSON requested\n')
  technologies = JSON.parse(response)
  # NOTE(heckj): this structure is specific to the technologies.json data format
  # that's used by the Apple Developer Site - current as of March 2021. Undocumented
  # (as you'd expect), so updates may be needed if the structure changes.
  technologies['sections'].each do |section|
    # puts("processing section")
    if section['kind'] == 'technologies'
      # puts("processing group")
      section['groups'].each do |techgroup|
        techgroup['technologies'].each do |tech|
          # example identifier: doc://com.apple.documentation/documentation/kernelmanagement
          uri = URI(tech['destination']['identifier'])
          if tech['languages'][0] != 'data'
            # puts(tech['title'])
            # puts(tech['destination']['identifier'])
            puts "Adding documentation URL: ", baseURI+uri.path
            spider.start_urls.append(baseURI+uri.path)
          else
            puts "DATA API: ", tech['title']
          end
        end
      end
    end
  end

  # print "Starting URLS: ", spider.start_urls, "\n"
  AppleDeveloperSpider.crawl!
end

task generate: ['tmp', '_data/frameworks'] do
  symbols = Parallel.map(Dir['tmp/**/*.json']) do |file|
    Oj.load(File.read(file))
  end

  Parallel.each(symbols.group_by { |symbol| symbol['framework'] }) do |name, symbols|
    next if name.nil? || name.empty?
    next if symbols.empty?

    slug = name.downcase.strip.gsub(' ', '-').gsub(/[^\w.-]/, '')
    filepath = File.join('_data/frameworks', slug) + '.json'

    framework = {}
    framework[:name] = name
    framework[:url] = 'https://developer.apple.com/documentation/' + URI.parse(symbols.flat_map { |symbol| symbol['url'] }.first).path.split(%r{/})[1]
    framework[:number_of_documented_symbols] = symbols.filter { |s| s['is_documented'] }.count
    framework[:number_of_undocumented_symbols] = symbols.filter { |s| !s['is_documented'] }.count
    framework[:symbols] = Parallel.flat_map(symbols) do |symbol|
      unless symbol['is_documented'] || symbol['type'] == 'Article' || symbol['type'] == 'Sample Code'
        symbol['breadcrumbs'] = symbol['breadcrumbs'].select { |b| !b.empty? && b != 'Deprecated' }.uniq[1..-1]

        case symbol['type']
        when /Property/, /Method/, /Initializer/, /Subscript/, 'Enumeration Case'
          symbol['name'] = begin
                               symbol['breadcrumbs'][-2..-1].join('.')
                           rescue StandardError
                             next
                             end
        when /Operator/
          symbol['name'] = begin
                               symbol['breadcrumbs'][-2..-1].reverse.join(' ')
                           rescue StandardError
                             next
                             end
        end

        symbol.select { |key, _value| %w[type url name breadcrumbs].include?(key) }
      end
    end.compact.sort_by { |symbol| symbol['name'] }

    File.write(filepath, Oj.dump(framework, mode: :compat))
  end
end

file '_site/' => [:build]

task :build do
  sh 'JEKYLL_ENV=production bundle exec jekyll build'
end

CLEAN << '_site'

file '.netlify/state.json' do
  sh 'netlify link'
end

CLOBBER << '.netlify'

task deploy: ['_site/', '.netlify/state.json'] do
  sh 'netlify deploy -d _site'
end

task publish: ['_site/'] do
  sh 'netlify deploy -d _site --prod'
end
