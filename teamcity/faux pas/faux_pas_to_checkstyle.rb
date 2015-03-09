#!/usr/bin/env ruby

require 'json'
require 'rexml/document'
require 'optparse'
require 'pathname'

def diagnostics_by_file_from_json_root(json_root)
  diagnostics_by_file = {}

  diagnostics = json_root[:diagnostics]
  diagnostics.each do |d|
    file_path = d[:file]
    diagnostics_for_file = diagnostics_by_file[file_path]
    if diagnostics_for_file.nil?
      diagnostics_for_file = []
      diagnostics_by_file[file_path] = diagnostics_for_file
    end

    diagnostics_for_file << d
  end
  
  diagnostics_by_file
end

def xml_element_from_diagnostic(diagnostic)
  diagnostic_element = REXML::Element.new('error')
  attributes = diagnostic_element.attributes
  
  checkstyle_source = "com.fauxpas.#{diagnostic[:ruleShortName]}"
  attributes['source'] = checkstyle_source
  
  info = diagnostic[:info] ? diagnostic[:ruleDescription].strip : ''
  rule_description = diagnostic[:ruleDescription] ? diagnostic[:ruleDescription].strip : ''
  rule_name = diagnostic[:ruleName] ?  diagnostic[:ruleName].strip : ''
  file_snippet = diagnostic[:fileSnippet] ? diagnostic[:fileSnippet].strip : ''
  
  faux_pas_severity = diagnostic[:severityDescription]
  checkstyle_severity =
  case faux_pas_severity
  when 'Concern' then 'info'
  when 'Warning' then 'warning'
  when 'Error'  then 'error'
  end
  
  attributes['severity'] = checkstyle_severity

  
  message = "#{rule_name} (#{rule_description}): #{file_snippet}. #{info}".strip
  attributes['message'] = message
  
  extent_hash = diagnostic[:extent]
  fail 'Can\'t find extent hash!' unless extent_hash
  
  extent_start_hash = extent_hash[:start]
  fail 'Can\'t find extent start hash!' unless extent_start_hash
  
  line = extent_start_hash[:line]
  
  column = extent_start_hash[:utf16Column]
  
  attributes['line'] = line
  attributes['column'] = column
  
  diagnostic_element
end

def xml_document_from_diagnostics(diagnostics_by_file)
  REXML::Document.new.tap do |xml_document|
    xml_document << REXML::XMLDecl.new
    
    checkstyle_element = REXML::Element.new('checkstyle', xml_document)
    
    diagnostics_by_file.each do |file_path, diagnostics| 
      REXML::Element.new('file', checkstyle_element).tap do |file_element|
        file_element.attributes['name'] = file_path
        diagnostics.each do |diagnostic|
          diagnostic_element = xml_element_from_diagnostic(diagnostic)
          file_element << diagnostic_element
        end
      end
    end
  end  
end

def json_string_to_xml_string(json_string)  
  json_root = JSON.parse(json_string, symbolize_names: true)
  fail 'Failed to parse JSON!' if json_root.nil?
  
  diagnostics_by_file = diagnostics_by_file_from_json_root(json_root)
  
  ''.tap { |xml_string| xml_document_from_diagnostics(diagnostics_by_file).write(output: xml_string, indent: 4) }
end

# Set encoding to UTF-8 since that's what both ends deal with.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

Options = Struct.new(:output_path)

options = Options.new
OptionParser.new do |opts|
  opts.banner = "Faux Pas JSON to Checkstyle XML Converter.\nUsage: #{opts.program_name} source_json.json"
  
  opts.on('-o [output_path.xml]', '--output [output_path.xml]', 'Path to output resulting XML. If not specified, use stdout.') do |output_path|
    output_pathname = Pathname.new(output_path)
    options.output_path = output_pathname
  end
  
  opts.on_tail('-h', '--help', 'Show this messages') do
    puts opts
  end
end.parse!

json_path = ARGV[0]
exit unless json_path

json_string = IO.read(json_path, encoding: 'UTF-8')
fail 'json string is empty!' if json_string.nil? || json_string.empty?

xml_string = json_string_to_xml_string(json_string)

if options.output_path
  IO.write(options.output_path, "#{xml_string.strip}\n")
else
  puts xml_string
end
