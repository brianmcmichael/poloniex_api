# Poloniex API Wrapper - Ruby Edition

* Ruby 2.15+ 
* No additional dependencies

Ported from [this](https://github.com/s4w3d0ff/python-poloniex) wrapper written by 's4w3d0ff'

> I (brianmcmichael) am not affiliated with, nor paid by Poloniex. If you wish to contribute to this repository please read CONTRIBUTING.md. All and any help is appreciated.

## Getting Started

Add the Api wrapper to your `Gemfile`

```
gem 'poloniex_api'
```

Require the gem in your application

```
require 'poloniex'
```

Basic Usage

```
poloniex = Poloniex::API.new
```


Initialize a new object with your API key, Secret Key, and timeout in seconds.

```
poloniex = Poloniex::API.new('YOUR_API_KEY', 'YOUR_SECRET_KEY', 3)
```

Get your API key [here](https://poloniex.com/apiKeys)



