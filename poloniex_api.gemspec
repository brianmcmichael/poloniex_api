# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'poloniex/version'

Gem::Specification.new do |s|
  s.name        = 'poloniex_api'
  s.version     = Poloniex::VERSION
  s.date        = '2017-08-27'
  s.summary     = "Poloniex API Wrapper"
  s.description = "An api wrapper for Poloniex, based on python API"
  s.authors     = ["Brian McMichael"]
  s.email       = 'brian@brianmcmichael.com'
  s.files       = ["lib/poloniex.rb", "lib/poloniex/exceptions.rb"]
  s.homepage    =
      'http://rubygems.org/gems/poloniex_api'
  s.license       = 'GPLv2'
end

