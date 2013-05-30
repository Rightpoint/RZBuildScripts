#!/usr/bin/env ruby

require 'clive'

module ABUpload

	class Uploader

		### Functions ###

		def upload_to_appblade(build_path, project_uuid, ci_token, ipa_path, dsym_name, version_string, release_track)
			
			output_path = FILE.realpath(build_path)
			full_ipa_path = FILE.join(output_path, ipa_path + ".ipa")
			dsym_path = FILE.realpath(dsym_name)
			puts "INSIDE THE APPBLADEUPLOADER!"

    		puts 'curl -# -H "Accept: application/json"  -H "Authorization: Bearer #{ci_token}" -F "version[bundle]=@#{full_ipa_path}" -F "version[dsym]=@#{dsym_path}" -F "version[commit_id]=#{version_string}" -F "version[version_string]=#{version_string}" -F "version[release_track_list]=#{release_track}" https://appblade.com/api/projects/#{project_uuid}/versions'
    		raise "Hey We did something wrong Return Code: #{$?}" if ($! != 0)
    	#	  curl -# -H "Authorization: Bearer $APPBLADE_JENKINS_OAUTH_TOKEN" -F "version[bundle]=@$IPA_PATH" -F "version[dsym]=@$DSYM_NAME" -F "version[commit_id]#=$GIT_TAG" -F "version[version_string]=$GIT_TAG" -F "version[changelog]=$RELEASE_CHANGELOG" -F "version[release_track_list]=$RELEASE_TRACK" \
  		#https://appblade.com/api/3/versions
		end
	end

end

#What is required:
# BuildPath, Project UUID, CIToken, ipa_path, 

class CLI < Clive
	opt :dsym, :dsym_name, arg: '<dsym_name>'
	opt :v, :version_string, arg: '<version_string>'
	opt :rt, :releast_track, arg: '<release_track>'
end

result = CLI.run

uploader = ABUpload::Uploader.new()

begin
	uploader.upload_to_appblade(result.args[0], result.args[1], result.args[2], result.args[3], result[:dsym_name], result[:version_string], result[:release_track])
rescue Exception
	puts "UPLOAD FAILED: #{$!}"
	return -1
else
	puts "UPLOAD SUCCEEDED!"
end
