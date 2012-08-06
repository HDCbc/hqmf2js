require_relative '../test_helper'

class HqmfJavascriptTest < Test::Unit::TestCase
  def setup
    # Open a path to all of our fixtures
    hqmf_contents = File.open("test/fixtures/NQF59New.xml").read
    
    doc = HQMF::Parser.parse(hqmf_contents, HQMF::Parser::HQMF_VERSION_2)
    
    codes_file_path = File.expand_path("../../fixtures/codes/codes.xml", __FILE__)
    # This patient is identified from Cypress as in the denominator and numerator for NQF59
    numerator_patient_json = File.read('test/fixtures/patients/larry_vanderman.json')
    
    # First compile the CoffeeScript that enables our converted HQMF JavaScript
    ctx = Sprockets::Environment.new(File.expand_path("../../..", __FILE__))
    Tilt::CoffeeScriptTemplate.default_bare = true 
    ctx.append_path "app/assets/javascripts"
    hqmf_utils = HQMF2JS::Generator::JS.library_functions
    
    # Parse the code systems that are mapped to the OIDs we support
    @codes_hash = HQMF2JS::Generator::CodesToJson.from_xml(codes_file_path)
    codes_json = HQMF2JS::Generator::CodesToJson.hash_to_js(@codes_hash)
    
    # Convert the HQMF document included as a fixture into JavaScript
    @converter = HQMF2JS::Generator::JS.new(doc)
    converted_hqmf = "#{@converter.js_for_data_criteria}
      #{@converter.js_for('IPP')}
      #{@converter.js_for('DENOM')}
      #{@converter.js_for('NUMER')}
      #{@converter.js_for('DENEXCEP')}
      #{@converter.js_for('DUMMY')}"

    # Now we can wrap and compile all of our code as one little JavaScript context for all of the tests below
    patient_api = File.open('test/fixtures/patient_api.js').read
    fixture_json = File.read('test/fixtures/patients/larry_vanderman.json')
    initialize_patient = 'var numeratorPatient = new hQuery.Patient(larry);'
    if RUBY_PLATFORM=='java'
      @context = Rhino::Context.new
    else
      @context = V8::Context.new
    end
    @context.eval("#{patient_api}
      #{hqmf_utils}
      var OidDictionary = #{codes_json};
      #{converted_hqmf}
      var larry = #{fixture_json};
      #{initialize_patient}")
  end
  
  def test_codes
    # Make sure we're recalling entries correctly
    assert_equal 1, @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.14"]').count
    assert_equal "00110", @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.14"]["HL7"][0]')
    
    # OIDs that are matched to multiple code systems should also work correctly
    # The list of supported OIDs will eventually be long, so this won't be an exhaustive test, just want to be sure the functionality is right
    assert_equal 3, @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.72"]').count
    assert_equal 2, @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.72"]["CPT"]').count
    assert_equal 3, @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.72"]["LOINC"]').count
    assert_equal 9, @context.eval('OidDictionary["2.16.840.1.113883.3.464.1.72"]["SNOMED-CT"]').count
  end
  
  def test_to_js_method
    value = @converter.to_js(@codes_hash)
    local_context = V8::Context.new
    patient_api = File.open('test/fixtures/patient_api.js').read
    hqmf_utils = HQMF2JS::Generator::JS.library_functions
    local_context.eval("#{patient_api}
                        #{hqmf_utils}
                        #{value}")
                        
    local_context.eval('typeof hqmfjs != undefined').must_equal true
    local_context.eval('typeof OidDictionary != undefined').must_equal true
    local_context.eval('typeof hqmfjs.IPP != undefined').must_equal true
    local_context.eval('typeof hqmfjs.NUMER != undefined').must_equal true
    local_context.eval('typeof hqmfjs.DENOM != undefined').must_equal true
  end
  
  def test_converted_hqmf
	# Patching of CodedEntry times
    assert_equal 1800, @context.eval("numeratorPatient.encounters()[0].asIVL_TS().low.asDate().getFullYear()")
    assert_equal 2010, @context.eval("numeratorPatient.encounters()[0].asIVL_TS().high.asDate().getFullYear()")

    # Measure variables
    assert_equal 2011, @context.eval("MeasurePeriod.low.asDate().getFullYear()")
    assert_equal 0, @context.eval("MeasurePeriod.low.asDate().getMonth()")
    assert_equal 2011, @context.eval("MeasurePeriod.high.asDate().getFullYear()")
    assert_equal 11, @context.eval("MeasurePeriod.high.asDate().getMonth()")
    assert_equal 2011, @context.eval("hqmfjs.MeasurePeriod()[0].asIVL_TS().low.asDate().getFullYear()")
    assert_equal 0, @context.eval("hqmfjs.MeasurePeriod()[0].asIVL_TS().low.asDate().getMonth()")
    assert_equal 2011, @context.eval("hqmfjs.MeasurePeriod()[0].asIVL_TS().high.asDate().getFullYear()")
    assert_equal 11, @context.eval("hqmfjs.MeasurePeriod()[0].asIVL_TS().high.asDate().getMonth()")
  
    # Age functions - Fixture is 37.1
    assert @context.eval("hqmfjs.ageBetween17and64(numeratorPatient)")
    assert @context.eval("hqmfjs.ageBetween30and39(numeratorPatient)")
    assert !@context.eval("hqmfjs.ageBetween17and21(numeratorPatient)")
    assert !@context.eval("hqmfjs.ageBetween22and29(numeratorPatient)")
    assert !@context.eval("hqmfjs.ageBetween40and49(numeratorPatient)")
    assert !@context.eval("hqmfjs.ageBetween50and59(numeratorPatient)")
    assert !@context.eval("hqmfjs.ageBetween60and64(numeratorPatient)")
    
    # Birthdate function
    assert_equal 1, @context.eval("hqmfjs.birthdateThirtyYearsBeforeMeasurementPeriod(numeratorPatient)").count
    assert_equal 0, @context.eval("hqmfjs.birthdateFiftyYearsBeforeMeasurementPeriod(numeratorPatient)").count

    # Gender functions - Fixture is male
    assert @context.eval("hqmfjs.genderMale(numeratorPatient)")
    assert !@context.eval("hqmfjs.genderFemale(numeratorPatient)")
    
    # Be sure the actual mechanic of code lists being returned works correctly - Using HasDiabetes as an example
    results = @context.eval("hqmfjs.HasDiabetes(numeratorPatient)[0]")['json']
    assert_equal 3, results['codes'].count
    assert_equal '250', results['codes']['ICD-9-CM'].first
    assert_equal 1270094400, results['time']
    
    # Encounters
    assert_equal 0, @context.eval("hqmfjs.EDorInpatientEncounter(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.AmbulatoryEncounter(numeratorPatient).length")
    
    # Conditions
    assert_equal 1, @context.eval("hqmfjs.HasDiabetes(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.HasGestationalDiabetes(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.HasPolycysticOvaries(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.HasSteroidInducedDiabetes(numeratorPatient).length")
    
    # Results
    assert_equal 2, @context.eval("hqmfjs.HbA1C(numeratorPatient).length")
    
    # Medications
    assert_equal 1, @context.eval("hqmfjs.DiabetesMedAdministered(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.DiabetesMedIntended(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.DiabetesMedSupplied(numeratorPatient).length")
    assert_equal 0, @context.eval("hqmfjs.DiabetesMedOrdered(numeratorPatient).length")
    
    # Standard population health query buckets
    assert @context.eval("hqmfjs.IPP(numeratorPatient)")
    assert @context.eval("hqmfjs.DENOM(numeratorPatient)")
    assert @context.eval("hqmfjs.NUMER(numeratorPatient)")
    assert !@context.eval("hqmfjs.DENEXCEP(numeratorPatient)")
    
    # COUNTing
    assert @context.eval("hqmfjs.moreThanTwoHbA1CTests(numeratorPatient)")
    assert !@context.eval("hqmfjs.moreThanFourHbA1CTests(numeratorPatient)")

    # UNIONing
    assert_equal 1, @context.eval("hqmfjs.anyDiabetes(numeratorPatient).length")

    # XPRODUCTing
    assert_equal 1, @context.eval("hqmfjs.allDiabetes(numeratorPatient).length")
  end
  
  def test_converted_utils
    # Filter events by value - HbA1C as an example
    events = 'numeratorPatient.results().match(getCodes("2.16.840.1.113883.3.464.1.72"))'
    assert_equal 2, @context.eval("filterEventsByValue(#{events}, new IVL_PQ(new PQ(9, '%'), null))").count
    assert_equal 0, @context.eval("filterEventsByValue(#{events}, new IVL_PQ(new PQ(10, '%'), null))").count
    
    # getCode
    assert_equal 1, @context.eval('getCodes("2.16.840.1.113883.3.464.1.14")').count
    assert_equal "00110", @context.eval('getCodes("2.16.840.1.113883.3.464.1.14")["HL7"][0]')
  end
  
  def test_map_reduce_generation
    hqmf_contents = File.open("test/fixtures/NQF59New.xml").read
    doc = HQMF::Parser.parse(hqmf_contents, HQMF::Parser::HQMF_VERSION_2)
    
    map_reduce = HQMF2JS::Converter.generate_map_reduce(doc)
    
    # Extremely loose testing here. Just want to be sure for now that we're getting results of some kind.
    # We'll test for validity over on the hQuery Gateway side of things.
    assert map_reduce[:map].include? 'map'
    assert map_reduce[:reduce].include? 'reduce'
    # Check functions to include actual HQMF converted function, HQMF utility function, and OID dictionary
    assert map_reduce[:functions].include? 'IPP'
    assert map_reduce[:functions].include? 'atLeastOneTrue'
    assert map_reduce[:functions].include? 'OidDictionary'
  end
  
  
  def test_missing_id
    
    context = HQMF2JS::Generator::ErbContext.new({})
    criteria = HQMF::DataCriteria.new(nil,nil,nil,nil,nil,nil,nil,'patient_characteristic',nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
    
    exception = assert_raise RuntimeError do
      n = context.js_name(criteria)
    end
    assert exception.message.match(/^No identifier for .*/)
  end  

end