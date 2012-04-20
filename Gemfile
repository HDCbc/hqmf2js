source "http://rubygems.org"

gem 'rails'

group :assets do
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
end

gem "hquery-patient-api", :git => 'http://github.com/pophealth/patientapi.git', :branch => 'develop'
#gem 'hquery-patient-api', :path => '../patientapi'
gem 'hqmf-parser', :git => 'https://github.com/pophealth/hqmf-parser.git', :branch => 'develop'
#gem 'hqmf-parser', :path => '../hqmf-parser'

gem 'nokogiri'
gem 'sprockets'
gem 'coffee-script'
gem 'uglifier'
gem 'tilt'
gem 'rake'
gem 'pry'

group :test do
  gem 'minitest'
  gem 'turn', :require => false
  gem 'cover_me', '~> 1.2.0'
  gem 'awesome_print', :require => 'ap'
  
  platforms :ruby do
    gem "therubyracer", :require => 'v8'
  end
  
  platforms :jruby do
    gem "therubyrhino"
  end
end
