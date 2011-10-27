require File.expand_path("../../test_helper", __FILE__)

class DocumentTest  < Test::Unit::TestCase
  def setup
    @hqmf_file_path = File.expand_path("../../fixtures/NQF_Retooled_Measure_0043.xml", __FILE__)
    @doc = HQMF::Document.new(@hqmf_file_path)
  end
  
  def test_parse
    doc = HQMF::Document.parse(@hqmf_file_path)
    assert_equal 'QualityMeasureDocument', doc.root.name
    assert_equal 'urn:hl7-org:v3', doc.root.namespace.href 
  end
  
  def test_metadata
    assert_equal "Pneumonia Vaccination Status for Older Adults (NQF 0043)", @doc.title
    assert_equal "The percentage of patients 65 years of age and older who have ever received a pneumococcal vaccine.", @doc.description
  end
  
  def test_attributes
    attr_list = @doc.all_attributes
    assert_equal 16, attr_list.length
  
    attr = @doc.attribute_for_code('MSRTP')
    assert_equal 'F8D5AD22-F49E-4181-B886-E5B12BEA8966', attr.id
    assert_equal '12', attr.value
    assert_equal 'm', attr.unit
    assert_equal 'Measurement period', attr.name

    attr = @doc.attribute('F8D5AD22-F49E-4181-B886-E5B12BEA8966e')
    assert_equal 'MSRED', attr.code
    assert_equal '00001231', attr.value
    assert_equal nil, attr.unit
    assert_equal 'Measurement end date', attr.name

    attr = @doc.attribute_for_code('MSRMD')
    assert_equal '12 month(s)', attr.value
  end
  
  def test_data_criteria
    data_criteria = @doc.all_data_criteria
    assert_equal 4, data_criteria.length
    
    assert_equal :characteristic, data_criteria[0].type
    assert_equal 'Patient characteristic: birth date', data_criteria[0].title
    assert_equal '52A541D7-9C22-4633-8AEC-389611894672', data_criteria[0].id
    assert_equal '2.16.840.1.113883.3.464.0001.14', data_criteria[0].code_list_id
    assert_equal :birthtime, data_criteria[0].property
    
    assert_equal :encounter, data_criteria[1].type
    assert_equal 'Encounter: encounter outpatient', data_criteria[1].title
    assert_equal '3CF573A8-34AE-408E-88D7-26A1016A140D', data_criteria[1].id
    assert_equal '2.16.840.1.113883.3.464.0001.49', data_criteria[1].code_list_id
    
    assert_equal :procedure, data_criteria[2].type
    assert_equal 'Procedure performed: Pneumococcal Vaccination all ages', data_criteria[2].title
    assert_equal '482902EC-E214-4FB4-8C5A-85A41250573C', data_criteria[2].id
    assert_equal '2.16.840.1.113883.3.464.0001.143', data_criteria[2].code_list_id
    
    assert_equal :medication, data_criteria[3].type
    assert_equal 'Medication administered: Pneumococcal Vaccine all ages', data_criteria[3].title
    assert_equal '10165EC8-53EE-4242-A20D-B1D21CE0DC73', data_criteria[3].id
    assert_equal '2.16.840.1.113883.3.464.0001.430', data_criteria[3].code_list_id
    
    criteria = @doc.data_criteria('10165EC8-53EE-4242-A20D-B1D21CE0DC73')
    assert_equal :medication, criteria.type
    assert_equal 'Medication administered: Pneumococcal Vaccine all ages', criteria.title
    assert_equal '10165EC8-53EE-4242-A20D-B1D21CE0DC73', criteria.id
    assert_equal '2.16.840.1.113883.3.464.0001.430', criteria.code_list_id

    begin
      criteria = @doc.data_criteria('foo')
      assert false, "Should raise exception for unknown data criteria"
    rescue => detail
    end
  end
  
end