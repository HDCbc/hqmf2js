# Top level include file that brings in all the necessary code
require 'bundler/setup'
require 'nokogiri'
require 'erb'
require 'ostruct'
require 'singleton'
require 'json'
require 'tilt'
require 'coffee_script'
require 'sprockets'
require 'execjs'

require_relative 'hqmf/utilities'
require_relative 'hqmf/types'
require_relative 'hqmf/document'
require_relative 'hqmf/data_criteria'
require_relative 'hqmf/population_criteria'
require_relative 'hqmf/precondition'

require_relative 'generator/js'
require_relative 'generator/codes_to_json'

Tilt::CoffeeScriptTemplate.default_bare = true
class HqmfUtility
  @@ctx = nil
  
  def self.ctx
    unless @@ctx
      @@ctx = Sprockets::Environment.new(File.expand_path("../../", __FILE__))
      @@ctx.append_path "app/assets/javascripts"
    end
    @@ctx
  end

  def self.hqmf_utility_javascript
    self.ctx.find_asset('hqmf_util')
  end
end

module HQMF2JS
  class Converter
    def self.generate_map_reduce(hqmf_contents)
      # First compile the CoffeeScript that enables our converted HQMF JavaScript
      ctx = Sprockets::Environment.new(File.expand_path("../../..", __FILE__))
      Tilt::CoffeeScriptTemplate.default_bare = true 
      ctx.append_path "app/assets/javascripts"
      hqmf_utils = HqmfUtility.hqmf_utility_javascript.to_s

      # Parse the code systems that are mapped to the OIDs we support
      codes_file_path = File.expand_path("../../test/fixtures/codes.xml", __FILE__)
      codes = Generator::CodesToJson.new(codes_file_path)
      codes_json = codes.json

      # Convert the HQMF document included as a fixture into JavaScript
      converter = Generator::JS.new(hqmf_contents)
      converted_hqmf = "#{converter.js_for_data_criteria}\n#{converter.js_for('IPP')}\n#{converter.js_for('DENOM')}\n#{converter.js_for('NUMER')}\n#{converter.js_for('DENEXCEP')}"
      
      # Pretty stock map/reduce functions that call out to our converted HQMF code stored in the functions variable
      map = "function map(patient) {
  if (typeof(IPP)==='function' && IPP(patient)) {
    emit('ipp', 1);
    if (typeof(DENOM)==='function' && DENOM(patient)) {
      if (typeof(NUMER)==='function' && NUMER(patient)) {
        emit('denom', 1);
        emit('numer', 1);
      } else if (typeof(DENEXCEP)==='function' && DENEXCEP(patient)) {
        emit('denexcep', 1);
      } else {
        emit('denom', 1);
        emit('antinum', 1);
      }
    }
  }
};"
      reduce = "function reduce(bucket, counts) {
  var sum = 0;
  while(counts.hasNext()){
    sum += counts.next();
  }
  return sum;
};"
      functions = "#{hqmf_utils}\nvar OidDictionary = #{codes_json};\n#{converted_hqmf}"

      return { :map => map, :reduce => reduce, :functions => functions }
    end
  end
end