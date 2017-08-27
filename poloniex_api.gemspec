# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'poloniex/version'

Gem::Specification.new do |s|
  s.name           = 'poloniex_api'
  s.version        = Poloniex::VERSION
  s.date           = '2017-08-27'
  s.summary        = "Poloniex API Wrapper"
  s.description    = "An API wrapper for Poloniex, built in Ruby"
  s.authors        = ["Brian McMichael"]
  s.email          = 'brian@brianmcmichael.com'
  s.files          = `git ls-files`.split("\n")
  s.require_paths  = ["lib"]
  s.homepage       =
      'http://rubygems.org/gems/poloniex_api'
  s.license        = 'GPLv2'
end

