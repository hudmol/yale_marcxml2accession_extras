if ASConstants.VERSION =~ /^[v|V]\.?1\.1\.0/

  MarcXMLBaseMap.module_eval do

    AUTH_SUBJECT_SOURCE = {
      'a'=>"Library of Congress Subject Headings",
      'b'=>"LC subject headings for children's literature",
      'c'=>"Medical Subject Headings",
      'd'=>"National Agricultural Library subject authority file",
      'k'=>"Canadian Subject Headings",
      'n'=>"Not applicable",
      'r'=>"Art and Architecture Thesaurus",
      's'=>"Sears List of Subject Headings",
      'v'=>"R\u00E9pertoire de vedettes-matic\u00E8re",
      'z'=>"Other"
    }

    BIB_SUBJECT_SOURCE = {
      '0'=>"Library of Congress Subject Headings",
      '1'=>"LC subject headings for children's literature",
      '2'=>"Medical Subject Headings",
      '3'=>"National Agricultural Library subject authority file",
      '4'=>"Source not specified",
      '5'=>"Canadian Subject Headings",
      '6'=>"R\u00E9pertoire de vedettes-matic\u00E8re"
    }

    def record_type(type_of_record = nil, subject_source = nil)
      @type ||= { type: :bibliographic, subject_source: nil }
      if type_of_record
        @type[:type] = type_of_record == 'z' ? :authority : :bibliographic
      end
      if subject_source
        @type[:subject_source] = subject_source and @type[:type] == :authority ? subject_source : nil
      end
      @type
    end

    alias_method :set_record_type, :record_type


    def sets_subject_source
      -> node {
        if record_type[:type] == :authority
          AUTH_SUBJECT_SOURCE[ record_type[:subject_source] ] || 'Source not specified'
        else
          BIB_SUBJECT_SOURCE[node.attr('ind2')] || ( !node.at_xpath("subfield[@code='2']").nil? ? node.at_xpath("subfield[@code='2']").inner_text : 'Source not specified' )
        end
      }
    end

  end
end
