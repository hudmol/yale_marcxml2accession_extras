

class YaleMarcXMLAccessionConverter < MarcXMLConverter
  def self.import_types(show_hidden = false)
    [
     {
       :name => "marcxml_accession",
       :description => "Import MARC XML records as Accessions (Yale)"
     }
    ]
  end

  def self.instance_for(type, input_file)
    if type == "marcxml_accession"
      self.new(input_file)
    else
      nil
    end
  end

end

# TODO - write some of this into the built-in MarcXMLAccessionConverter
# class's configure method so it can be inherited.
YaleMarcXMLAccessionConverter.configure do |config|

  config["/record"][:obj] = :accession
  config["/record"][:map].delete("//controlfield[@tag='008']")
  config["/record"][:map].delete("self::record")


  # strip mappings that target .notes
  config["/record"][:map].each do |path, defn|
    next unless defn.is_a?(Hash)
    if defn[:rel] == :notes
      config["/record"][:map].delete(path)
    end
  end


  # strip other mappings that target resource-only properties
  [
   "datafield[@tag='536']" # finding_aid_sponsor
  ].each do |resource_only_path|
    config["/record"][:map].delete(resource_only_path)
  end

  # access restrictions
  config["/record"][:map]["datafield[@tag='506']"] = -> record, node {
    node.xpath("subfield").each do |sf|
      val = sf.inner_text
      unless val.empty?
        record.access_restrictions_note ||= ""
        record.access_restrictions_note += " " unless record.access_restrictions_note.empty?
        record.access_restrictions_note += val
      end
    end

    if node.attr('ind1') == '1'
      record.access_restrictions = true
    end
  }


  config["/record"][:map]["datafield[@tag='540']"] = -> record, node {
    node.xpath("subfield").each do |sf|
      val = sf.inner_text
      unless val.empty?
        record.use_restrictions_note ||= ""
        record.use_restrictions_note += " " unless record.use_restrictions_note.empty?
        record.use_restrictions_note += val
      end
    end

    record.use_restrictions = true
  }


  config["/record"][:map]["datafield[@tag='541']"] = -> record, node {
    provenance1 = ""

    node.xpath("subfield").each do |sf|
      val = sf.inner_text

      unless val.empty?
        provenance1 += " " unless provenance1.empty?
        provenance1 += val
      end
    end

    if record.provenance
      record.provenance = provenance1 + " #{record.provenance}"
    elsif provenance1.length > 0
      record.provenance = provenance1
    end
  }


  config["/record"][:map]["datafield[@tag='561']"] = -> record, node {
    provenance2 = ""

    node.xpath("subfield").each do |sf|
      val = sf.inner_text

      unless val.empty?
        provenance2 += " " unless provenance2.empty?
        provenance2 += val
      end
    end

    if record.provenance
      record.provenance = "#{record.provenance} "  + provenance2
    elsif provenance2.length > 0
      record.provenance = provenance2
    end
  }


  # Yale Extension stuff:

  # user_defined fields
  {
    '020' => 'string_4',
    '022' => 'string_4',
    '099' => 'string_2',
    '130' => 'text_2',
    # ['260', '$a'] => 'string_3',
    # ['264', '$a'] => 'string_3',
    '490' => 'text_3',
    '510' => 'text_5',
  }.each do |code, target|

    path = code.is_a?(Array) ? "datafield[@tag='#{code[0]}']/subfield[@code='#{code[1]}']" : "datafield[@tag='#{code}']"

    config["/record"][:map][path] = -> accession, node {
      accession.user_defined ||= ASpaceImport::JSONModel(:user_defined).new
      if accession.user_defined[target]
        accession.user_defined[target] += " #{node.inner_text}"
      else
        accession.user_defined[target] = node.inner_text
      end
    }
  end

  # title(s)
  %w(210 222 240 242 245 246).each do |tag|
    config["/record"][:map]["datafield[@tag='#{tag}']"] = -> accession, node {
      accession['_titles'] ||= {}
      accession['_titles'][tag] = MarcXMLConverter.subfield_template("{$a : }{$b }{[$h] }{$k , }{$n , }{$p , }{$s }{/ $c}", node)

      if tag == '245'
        expression = MarcXMLConverter.concatenate_subfields(%w(f g), node, '-')
        unless expression.empty?
          if accession.dates[0]
            accession.dates[0]['expression'] = expression
          else
            make(:date)  do |date|
              date.label = 'creation'
              date.date_type = 'inclusive'
              date.expression = expression
              accession.dates << date
            end
          end
        else
          accession['_needs_date'] = true
        end
      end
    }
  end

  # content_description
  %w(250 254 255 256 257 258 306 340 342 343 351 352 500 501 502 504 507 508 511 513 514 518 520 524 530 533 534 535 536 538 544 546 555 562 563 580 581 590 591 592 593 594 595 596 597 598 599).each do |tag|
    config["/record"][:map]["datafield[@tag='#{tag}']"] = -> accession, node {
      accession['_content_descriptions'] ||= {}
      accession['_content_descriptions'][tag] = node.inner_text
    }
  end

  # inventory
  config["/record"][:map]["datafield[@tag='505']"] = :inventory

  # 260 & 264
  ['260', '264'].each do |tag|
    config["/record"][:map]["datafield[@tag='#{tag}']/subfield[@code='a']"] = -> accession, node {
      accession.user_defined ||= ASpaceImport::JSONModel(:user_defined).new
      if accession.user_defined['string_3']
        accession.user_defined['string_3'] += " #{node.inner_text}"
      else
        accession.user_defined['string_3'] = node.inner_text
      end
    }

    config["/record"][:map]["datafield[@tag='#{tag}']/subfield[@code='b']"] = {
      :obj => :agent_person,
      :rel => -> accession, agent {
        accession[:linked_agents] << {
          :role => 'creator',
          :relator => 'pbl',
          :ref => agent.uri
        }
      },
      :map => {
        "self::subfield" => {
          :obj => :name_person,
          :rel => :names,
          :map => {
            "self::subfield" => MarcXMLConverter.sets_primary_and_rest_of_name
          },
          :defaults => {
            :name_order => 'direct',
            :source => 'ingest'
          }
        }
      }
    }

    # date of publication
    config["/record"][:map]["datafield[@tag='#{tag}']/subfield[@code='c']"] = -> accession, node {
      
      date_begin, date_end = nil
      date_type = 'single'
      
      if  node.inner_text.strip =~ /^([0-9]{4})-([0-9]{4})$/
        date_begin,date_end = node.inner_text.strip.split("-")  
        date_type = "range"
      end

      date = ASpaceImport::JSONModel(:date).new
      date.label = 'publication'
      date.date_type = date_type
      date.begin = date_begin
      date.end = date.end
      date.expression = node.inner_text

      accession.dates << date
    }

    # a few more subjects
    config["/record"][:map]["datafield[@tag='730' or @tag='740']"] = MarcXMLConverter.
      subject_template(
                       -> node {
                         terms = []
                         terms << MarcXMLConverter.make_term('uniform_title', MarcXMLConverter.concatenate_subfields(%w(a d e f g h k l m n o p r s t), node, ' '))
                         node.xpath("subfield").each do |sf|
                           terms << MarcXMLConverter.make_term(
                                              {
                                                'v' => 'genre_form',
                                                'x' => 'topical',
                                                'y' => 'temporal',
                                                'z' => 'geographic'
                                              }[sf.attr('code')], sf.inner_text)
                         end
                         terms
                       },
                       MarcXMLConverter.sets_subject_source)



    # This has to be last
    config["/record"][:map]["self::record"] = -> accession, node {

      if accession['_titles']
        accession.title = accession['_titles'].sort.map {|e| e[1]}.join(' ')
      end

      if !accession.title && accession['_fallback_titles'] && !accession['_fallback_titles'].empty?
        accession.title = accession['_fallback_titles'].shift
      end

      if accession.id_0.nil? or accession.id.empty?
        accession.id_0 = "imported-#{SecureRandom.uuid}"
      end

      accession.accession_date = Time.now.to_s.sub(/\s.*/, '')

      Log.debug("CONTENT_DESCRIPTIONS")
      Log.debug(accession['_content_descriptions'])
      
      if accession['_content_descriptions']
        accession.content_description = accession['_content_descriptions'].sort.map {|e| e[1]}.join(' ')
      end
    }



  end      

end



