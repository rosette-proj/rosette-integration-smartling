[![Build Status](https://travis-ci.org/rosette-proj/rosette-tms-smartling.svg)](https://travis-ci.org/rosette-proj/rosette-tms-smartling) [![Code Climate](https://codeclimate.com/github/rosette-proj/rosette-tms-smartling/badges/gpa.svg)](https://codeclimate.com/github/rosette-proj/rosette-tms-smartling) [![Test Coverage](https://codeclimate.com/github/rosette-proj/rosette-tms-smartling/badges/coverage.svg)](https://codeclimate.com/github/rosette-proj/rosette-tms-smartling/coverage)

rosette-tms-smartling
===========================

A Rosette TMS (Translation Management System) that stores phrases and translations via [Smartling](https://smartling.com), a 3rd-party translation service.

## Installation

`gem install rosette-tms-smartling`

Then, somewhere in your project:

```ruby
require 'rosette/tms/smartling-tms'
```

### Introduction

This library is generally meant to be used with the Rosette internationalization platform. TMSs are configured per repo, so adding the Smartling TMS might cause your Rosette config to look like this:

```ruby
require 'rosette/core'
require 'rosette/tms/smartling-tms'
require 'rosette/serializers/yaml-serializer'

rosette_config = Rosette.build_config do |config|
  config.add_repo('my-awesome-repo') do |repo_config|
    repo_config.use_tms('smartling') do |tms_config|
      tms_config.set_serializer('yaml/rails')
      tms_config.set_api_options(
        smartling_api_key: 'fookey', smartling_project_id: 'fooid'
      )
    end
  end
end
```

### Additional Configuration Options

rosette-tms-smartling supports additional configuration options:

#### Directives

Smartling directives give Smartling special instructions regarding how to interpret the files you send it. See [their documentation](http://docs.smartling.com/pages/supported-file-types/) for the supported directives for your file type. Note: Rosette determines the file type from the serializer you've told it to use, i.e. whatever you passed to `#set_serializer`.

```ruby
repo_config.add_serializer('rails', format: 'yaml/rails')
repo_config.use_tms('smartling') do |tms_config|
  tms_config.set_directives(%Q[
    # smartling.plurals_detection = off
    # smartling.placeholder_format_custom = (\{\{.+?\}\})
  ])
end
```

#### Parse Frequency

rosette-tms-smartling looks up translations by maintaining an in-memory database downloaded and parsed from your Smartling project's translation memory. Translation memories contain all the translations that have ever been published in Smartling, and for this reason they can be very large. To avoid downloading and parsing the translation memory for every translation lookup, rosette-tms-smartling caches the download and parse result. All subsequent lookups will use the cache. After a certain amount of time has passed (called the "parse frequency"), the translation memory will be automatically re-downloaded on the next lookup. The default parse frequency is 1 hour. To avoid slow lookups in between refreshes, call the `#re_download_memory` method:

```ruby
rosette_config.get_repo('my-awesome-repo').tms.re_download_memory
```

You can also set your own parse frequency (in seconds) during configuration:

```ruby
repo_config.use_tms('smartling') do |tms_config|
  tms_config.set_parse_frequency(1800)  # 30 minutes
end
```

#### Thread Pool Size

Certain operations - eg. downloading translation memories for all locales - happen in parallel using multiple JVM threads. You can specify the maximum number of threads you want rosette-tms-smartling to use by using the `#set_thread_pool_size` method during configuration:

```ruby
repo_config.use_tms('smartling') do |tms_config|
  tms_config.set_thread_pool_size(5)
end
```

## Requirements

This project must be run under jRuby. It uses [expert](https://github.com/camertron/expert) to manage java dependencies via Maven. Run `bundle exec expert install` in the project root to download and install java dependencies.

## Running Tests

`bundle exec rake` or `bundle exec rspec` should do the trick.

## Authors

* Cameron C. Dutro: http://github.com/camertron
