#!/usr/bin/env ruby

require 'clive'

module ABUpload

	class Uploader

		### Functions ###

		def upload_to_appblade(ci_token, ipa_path, dsym_name, version_string, release_track)
            puts "CI Token: ",ci_token
            puts "IPA Path: ",ipa_path
            puts "dSYM Path: ",dsym_name
            puts "Version String: ",version_string
            puts "Release Track: ",release_track
            
			full_ipa_path = File.realpath(ipa_path)
            
            dsym_path = File.realpath(dsym_name)

    		puts `curl -# -H "Accept: application/json"  -H "Authorization: Bearer #{ci_token}" -F "version[bundle]=@#{full_ipa_path}" -F "version[dsym]=@#{dsym_path}" -F "version[commit_id]=#{version_string}" -F "version[version_string]=#{version_string}" -F "version[release_track_list]=#{release_track}" https://appblade.com/api/3/versions`
            
    		raise "Error uploading application: #{$?}" if ($! != 0)
		end
	end

end

# What is required:
# BuildPath, CIToken, ipa_path, 

class CLI < Clive
	opt :d, :dsym_name, arg: '<dsym_name>'
	opt :v, :version_string, arg: '<version_string>'
	opt :r, :release_track, arg: '<release_track>'
end

result = CLI.run

uploader = ABUpload::Uploader.new()

begin
    puts "Begining the upload to Appblade Proccess"
	uploader.upload_to_appblade(result.args[0], result.args[1], result[:dsym_name], result[:version_string], result[:release_track])
rescue Exception
	puts "UPLOAD FAILED: #{$!}"
	return -1
else
	puts "UPLOAD SUCCEEDED!"
end
