#!/usr/bin/env ruby

require 'clive'

module ResignBuild

	class Resigner

		### Functions ###

		def path_in_payload(output_path, xcode_target,path_component)
			payload = File.join(output_path, "Payload")
			payload_target = File.join(payload, xcode_target)
			code_signature = File.join(payload_target, path_component)
			return code_signature
		end

		def unzip_ipa(ipa_path) 
            puts `unzip "#{full_ipa_path}"`
            raise "Error Unzipping IPA: #{ipa_path} Make sure the file exists.  Return Code: #{$?}" if ($? != 0)
		end

		def remove_old_code_signature(output_path, xcode_target)
			code_signature = path_in_payload(output_path,xcode_target,"_codeSignature") 
			code_resource = path_in_payload(output_path,xcode_target,"CodeResources")
            puts `rm -r "#{code_signature}" "#{code_resource}" 2> /dev/null | true`
		end

		def add_new_provisioning_profile(output_path, provisioning_profile, target_name)
			provisioning_profile_path = path_in_payload(output_path,xcode_target,"embedded.mobileprovision")

			puts `cp "#{provisioning_profile}" "#{provisioning_profile_path}"`
		end

		def add_new_cert(output_path, target_name, cert_file, cert_password)
            cert_sha1 = getCert_sha1(cert_full_path, cert_password)
            resource_rules = path_in_payload(output_path, xcode_target, "ResourceRules.plist")

			puts `/usr/bin/codesign -f -s "#{cert_sha1}" --resources-rules "#{resource_rules}" "Payload/#{xcode_target}"`
		end

		def zip_up_new_ipa(output_ipa_path)
            puts `zip -qr "#{output_ipa_path}" Payload`
		end

		def get_cert_sha1(cert_file, cert_password)
	      der_cert = OpenSSL::PKCS12.new(File.read(cert_file), cert_password).certificate.to_der
	      sha1 = OpenSSL::Digest::SHA1.new der_cert
	      puts "Cert SHA-1:", sha1.to_s.upcase
	      return sha1.to_s.upcase
	    end

		def resign_build(build_path, ipa_path, xcode_target, signing_path, output_ipa_name, provisioning_profile, cert_path, cert_password)
			puts "Build Path: ",build_path
            puts "IPA Path: ",ipa_path
            puts "XCode Target Name: ",xcode_target
            puts "Signing Path: ",signing_path
            puts "Provisioning Profile: ",provisioning_profile
            puts "Cert File: ", cert_path
            puts "Cert Password: ", cert_password
            puts "Output IPA Name: ", output_ipa_name
            
			output_path = File.realpath(build_path)
			signing_path = File.realpath(signing_path)
			full_ipa_path = File.join(output_path, ipa_path)
			output_ipa_path = File.join(output_path, output_ipa_name)
            cert_full_path = File.join(signing_path, cert_path)
            provisioning_profile_path = File.join(signing_path, provisioning_profile)

            unzip_ipa(full_ipa_path)

            remove_old_code_signature(output_path, xcode_target)

			add_new_provisioning_profile(output_path, provisioning_profile_path, target_name)

			add_new_cert(output_path, target_name, cert_full_path, cert_password)

			zip_up_new_ipa(output_ipa_path)


            # puts `unzip "#{full_ipa_path}"`
            #puts `rm -r "Payload/#{xcode_target}/_codeSignature" "Payload/#{xcode_target}/CodeResources" 2> /dev/null | true`
            #puts `cp "#{provisioning_profile_path}" "Payload/#{xcode_target}/embedded.mobileprovision"`
            # puts `/usr/bin/codesign -f -s "#{cert_sha1}" --resources-rules "Payload/#{xcode_target}/ResourceRules.plist" "Payload/#{xcode_target}"`
            # puts `zip -qr "#{output_ipa_path}" Payload`
            
    		raise "Error Resigning application: #{$?}" if ($! != 0)

    		# Repackage AppStore as AdHoc
			  # cd "${PROJECT_PATH}build/${BuildConfiguration}-iphoneos/"
			  # unzip "${APP_NAME}-${BuildConfiguration}.ipa"
			  # rm -r "Payload/${XCODE_TARGET_NAME}/_CodeSignature" "Payload/${XCODE_TARGET_NAME}/CodeResources" 2> /dev/null | true
			  # cp "${WORKSPACE}/${SIGNING_PATH}KrushAdHocProfile.mobileprovision" "Payload/${XCODE_TARGET_NAME}/embedded.mobileprovision"
			  # #This is the Krush Distrobution Cert SHA1
			  # /usr/bin/codesign -f -s "0DA3DF1BDA8F1D47C823450943B8B11ACB046723" --resource-rules "Payload/${XCODE_TARGET_NAME}/ResourceRules.plist" "Payload/${XCODE_TARGET_NAME}"
			  # zip -qr "${APP_NAME}-${BuildConfiguration}-AdHoc.ipa" Payload
		end
	end

end

# What is required:
# BuildPath, CIToken, ipa_path, 

class CLI < Clive
	opt :pro, :provisioning_profile, arg: '<provisioning_profile>'
	opt :path, :cert_path, arg: '<cert_path>'
	opt :pass, :cert_password, arg: '<cert_password>'
end

result = CLI.run

resigner = ResignBuild::Resigner.new()

begin
	
    puts "Begining the Resign Process"
    resigner.resign_build(result.args[0], result.args[1], result.args[2], result.args[3], result.args[4], result[:provisioning_profile], result[:cert_path], result[:cert_password])
rescue Exception
	puts "RESIGN FAILED: #{$!}"
	return -1
else
	puts "RESIGN SUCCEEDED!"
end
