#!/usr/bin/env ruby

require 'clive'
require 'openssl'

module ResignBuild
    
	class Resigner
        
		### Functions ###
        
        def root_zip_path()
            return "/var/tmp/jenkins/build/"
        end
		def path_in_payload(output_path, xcode_target,path_component)
			payload = File.join(output_path, "Payload")
			payload_target = File.join(payload, xcode_target)
			code_signature = File.join(payload_target, path_component)
			return code_signature
		end
        
		def unzip_ipa(ipa_path)
            puts "Unizipping the IPA: ",ipa_path
            root_path = root_zip_path()
            puts `rm -r -v "#{root_path}"` if File.exists?(root_path)
            puts `unzip -u "#{ipa_path}"  -d "#{root_path}"`
            raise "Error Unzipping IPA: #{ipa_path} Make sure the file exists.  Return Code: #{$?}" if ($? != 0)
		end
        
		def remove_old_code_signature(xcode_target)
            puts "Removing old Code Signature: ",xcode_target
            root_path = root_zip_path()
			code_signature = path_in_payload(root_path,xcode_target,"_codeSignature")
			code_resource = path_in_payload(root_path,xcode_target,"CodeResources")
            puts `rm -r "#{code_signature}" "#{code_resource}" 2> /dev/null | true`
		end
        
		def add_new_provisioning_profile(provisioning_profile, xcode_target)
            puts "Adding new provisioning Profile: ", provisioning_profile
            root_path = root_zip_path()

			provisioning_profile_path = path_in_payload(root_path,xcode_target,"embedded.mobileprovision")
            
			puts `cp "#{provisioning_profile}" "#{provisioning_profile_path}"`
		end
        
		def add_new_cert(xcode_target, cert_file, cert_password)
            puts "Adding new Cert"
            root_path = root_zip_path()

            cert_sha1 = get_cert_sha1(cert_file, cert_password)
            resource_rules = path_in_payload(root_path, xcode_target, "ResourceRules.plist")
			puts `/usr/bin/codesign -f -s "#{cert_sha1}" --resource-rules "#{resource_rules}" "#{root_path}/Payload/#{xcode_target}"`
		end
        
		def zip_up_new_ipa(output_ipa_path)
            puts "Zipping up the new IPA"
            root_path = root_zip_path()
            
            puts "Output path: ",output_ipa_path
            
            puts `zip -qr "#{output_ipa_path}" "#{root_path}/Payload"`
		end
        
		def get_cert_sha1(cert_file, cert_password)
            der_cert = OpenSSL::PKCS12.new(File.read(cert_file), cert_password).certificate.to_der
            sha1 = OpenSSL::Digest::SHA1.new der_cert
            puts "Cert SHA-1:", sha1.to_s.upcase
            return sha1.to_s.upcase
	    end
        
		def resign_build(ipa_path, xcode_target, output_ipa_name, provisioning_profile, cert_path, cert_password)
            puts "IPA Path: ",ipa_path
            puts "XCode Target Name: ",xcode_target
            puts "Provisioning Profile: ",provisioning_profile
            puts "Cert File: ", cert_path
            puts "Cert Password: ", cert_password
            puts "Output IPA Name: ", output_ipa_name
            
			full_ipa_path = File.realpath(ipa_path)
            puts "Full IPA Path: ",full_ipa_path
            
            ipa_directory = File.dirname(full_ipa_path)
            puts "IPA directory: ",ipa_directory
            
			output_ipa_path = File.join(ipa_directory, File.basename(output_ipa_name))
            puts "Output IPA Path: ",output_ipa_path
            
            cert_full_path = File.realpath(cert_path)
            puts "Cert Full Path: ", cert_full_path
            
            provisioning_profile_path = File.realpath(provisioning_profile)
            puts "Provis Profile Path: ",provisioning_profile_path
            
            unzip_ipa(full_ipa_path)
            
            remove_old_code_signature(xcode_target)
            
			add_new_provisioning_profile(provisioning_profile, xcode_target)
            
			add_new_cert(xcode_target, cert_path, cert_password)
            
			zip_up_new_ipa(output_ipa_path)
            
            puts "Finished Resigning."
            
            puts "File Does exist : " if(File.exists?(output_ipa_path))
            
    		raise "Error Resigning application: #{$?}" if ($! != 0)
            
		end
	end
    
end

# What is required:
# BuildPath, CIToken, ipa_path,

class CLI < Clive
	opt :p, :cert_password, arg: '<cert_password>'
end

result = CLI.run

resigner = ResignBuild::Resigner.new()

begin
	
    puts "Begining the Resign Process"
    resigner.resign_build(result.args[0], result.args[1], result.args[2], result.args[3], result.args[4], result[:cert_password])
    rescue Exception
	puts "RESIGN FAILED: #{$!}"
	return -1
    else
	puts "RESIGN SUCCEEDED!"
end
