#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.expand_path('./lib', __dir__))

require 'dotenv/load'
require 'loop'
require 'config'
require 'stdout_logger'
require 'app_version'

logger = StdoutLogger.new

logger.info 'Shelly collector for SOLECTRUS, ' \
       "Version #{AppVersion.current || '<unknown>'}, " \
       "built at #{ENV.fetch('BUILDTIME', '<unknown>')}"
logger.info 'https://github.com/solectrus/shelly-collector'
logger.info 'Copyright (c) 2024-2026 Georg Ledermann, released under the MIT License'
logger.info "\n"

config = Config.from_env
config.logger = logger

logger.info "Using Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}"
config.log_config

Loop.start(config:)
