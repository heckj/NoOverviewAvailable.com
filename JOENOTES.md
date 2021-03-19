# Working Notes

brew install rbenv
rbenv install
rbenv init
gem install bundler:2.0.2
bundler install
# gem install ffi -v '1.11.1' --source 'https://rubygems.org/'
rake clean
rake scrape

## Non-mechanize spiders

    brew cask install google-chrome
    brew cash install chromedriver
    brew install phantomjs

## Interactive scraping experiments with Nokogiri

details references from <https://www.scrapingbee.com/blog/web-scraping-ruby/>

`irb`:

    require 'open-uri'
    require 'nokogiri'
    html = open("https://developer.apple.com/documentation/swiftui")
    response = Nokogiri::HTML(html)
    response.css("p").text