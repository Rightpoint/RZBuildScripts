#!/usr/bin/env ruby


require 'clive'
require 'openssl'

module XCBuild
  
  class Builder
    
    ### Functions ###
    def create_keychain(keychain, password="")
      #TODO - Check to see if keychain already exists
      puts `security create-keychain -p "#{password}" "#{keychain}"`
      puts "Create Keychain Return: ", $?
      #TODO - Detect and Return Error
    end
    
    def unlock_keychain(keychain, password="")
      puts `security unlock-keychain -p "#{password}" "#{keychain}"`
      puts "Unlock Keychain Return: ", $?
      raise "Error unlocking keychain #{keychain} Return Code: #{$?}" if ($? != 0)
    end
    
    def set_default_keychain(keychain)
      puts `security default-keychain -s "#{keychain}"`
      puts "Default Keychain Return: ", $?
      raise "Error setting default keychain #{keychain} Return Code: #{$?}" if ($? != 0)
      #TODO - Detect and Return Error
    end
    
    def install_signing(signing_cert, keychain="login", password="")
      puts `security import "#{signing_cert}" -k "#{keychain}" -P "#{password}" -T /usr/bin/codesign`
      puts "Signing Return: ", $?
      raise "Error installing signing certificate #{signing_cert} in keychain #{keychain} Return Code: #{$?}" if ($? != 0)
    end
    
    def get_cert_sha1(cert_file)
      der_cert = OpenSSL::PKCS12.new(File.read(cert_file)).certificate.to_der
      sha1 = OpenSSL::Digest::SHA1.new der_cert
      puts "Cert SHA-1:", sha1.to_s.upcase
      return sha1.to_s.upcase
    end
    
    def install_provisioning_profile(provisioning_profile)
      dest_path = File.join(File.expand_path("~/Library/MobileDevice/Provisioning Profiles"), File.basename(provisioning_profile))
      
      puts "Comparing Source:#{provisioning_profile} to Dest: #{dest_path} Compare:#{File.identical?(provisioning_profile, dest_path)}"
      
      if File.identical?(provisioning_profile, dest_path)
        puts "Provisioning Profiles are the same. Skipping install."
        return
      end
      
      puts `cp -f "#{provisioning_profile}" "#{dest_path}"`
      puts "Provisioning Profile Install Return: ", $?
      raise "Error installing provisioning profile #{provisioning_profile} in #{`echo ~/Library/MobileDevice/Provisioning\ Profiles/`} Return Code: #{$?}" if ($? != 0)
    end
    
    def clean_xcode_project(xcode_project)
      puts `xcodebuild -project "#{xcode_project}" -alltargets clean`
      puts "Xcode Clean Return: ", $?
      raise "Error cleaning Xcode Project #{xcode_project} Return Code: #{$?}" if ($? != 0)
    end
    
    def build_xcode_configuration(xcode_project, configuration, target=nil, signing_ident=nil)
      if (nil == target && nil == signing_ident)
        puts `xcodebuild -project "#{xcode_project}" -configuration "#{configuration}"`
      elsif (nil == target)
        puts `xcodebuild -project "#{xcode_project}" -configuration "#{configuration}" CODE_SIGN_IDENTITY="#{signing_ident}"`
      elsif (nil == signing_ident)
        puts `xcodebuild -project "#{xcode_project}" -target "#{target}" -configuration "#{configuration}"`
      else
        puts `xcodebuild -project "#{xcode_project}" -target "#{target}" -configuration "#{configuration}" CODE_SIGN_IDENTITY="#{signing_ident}"`
      end
      
      puts "Xcode Build Return: ", $?
      raise "Error building configuration #{configuration} for target #{target} in Xcode Project #{xcode_project} with signing identity #{signing_ident} Return Code: #{$?}" if ($? != 0)
    end
    
    def clean_package_files(build_path, package_name)
      zip_path = File.join(build_path, package_name + ".dSYM.zip")
      ipa_path = File.join(build_path, package_name + ".ipa")
      
      puts `rm -r "#{zip_path}"` if File.exists?(zip_path)
      puts "Clean Old dSYM Return: ", $?
      raise "Error removing old dSYM zip file #{zip_path} Return Code: #{$?}" if ($? != 0)
      puts `rm -r "#{ipa_path}"` if File.exists?(ipa_path)
      puts "Clean Old IPA Return: ", $?
      raise "Error removing old IPA file #{ipa_path} Return Code: #{$?}" if ($? != 0)
    end
    
    def package_xcode_build_configuration(configuration, target_name, build_path, project_name, signing_ident, provisioning_profile)
      config_build_path = File.join(build_path, configuration + "-iphoneos")
      package_name = target_name + "-" + configuration
      
      # Clean any previous package files
      clean_package_files(config_build_path, package_name)
      
      target_build_path = File.join(config_build_path, "#{target_name}.app")
      output_path = File.join(config_build_path, package_name + ".ipa")
      
      puts `xcrun -sdk iphoneos PackageApplication -v "#{target_build_path}" -o "#{output_path}" --sign #{signing_ident} --embed "#{provisioning_profile}"`
      puts "Xcrun Package Application Return: ", $?
      raise "Error packaging application #{target_build_path} with signing certificate #{signing_ident} provisioning profile #{provisioning_profile} output file #{output_path} Return Code: #{$?}" if ($? != 0)
      
      target_dsym_path = target_build_path + ".dsym"
      dsym_zip_file = target_dsym_path + ".zip"
      
      puts `zip "#{dsym_zip_file}" -r "#{target_dsym_path}"`
      puts "Zip dSYM Return: ", $?
      raise "Error zipping up dSYM file #{target_dsym_path} Return Code: #{$?}" if ($? != 0)
      [output_path, dsym_zip_file]
    end

    def build_and_package_configuration(projectFile, configuration, signingCert, mobileProvision, output_dir=".", certPassword="", keychain="jenkins.keychain", keychainPassword=nil, target_name=nil)
      
      ## Build Variables ###
      projectFilePath = File.realpath(projectFile)
      projectPath = File.dirname(projectFilePath)
      projectName = File.basename(projectFilePath, ".xcodeproj")
      
      target_name = projectName if nil == target_name
      
      dsymName = target_name + ".app.dSYM"
      buildPath=File.join(projectPath, 'build')
      
      provisioningProfile = File.realpath(mobileProvision[0])
      
      puts "Project Path: ", projectPath
      puts "Project Name: ", projectName
      puts "Build Path: ", buildPath
      
      puts "Xcode Target Name: ", target_name
      puts "DSYM Name: ", dsymName
      puts "Build Path: ", buildPath
      
      ### Install Signing Certs and Provisioning Profiles ###
      install_provisioning_profile(provisioningProfile)
      create_keychain(keychain, keychainPassword)
      unlock_keychain(keychain, keychainPassword)
      set_default_keychain(keychain)
      install_signing(signingCert, keychain)
      
      signingIdentity = get_cert_sha1(signingCert)
      
      ### Clean Xcode Targets ###
      clean_xcode_project(projectFilePath)
      
      ### Build Xcode Configuration ###
      build_xcode_configuration(projectFilePath, configuration, target_name, signingIdentity)
      
      ### Package Application ###
      products = package_xcode_build_configuration(configuration, target_name, buildPath, projectName, signingIdentity, provisioningProfile)
      
      puts "Products: #{products} OutputDir: #{output_dir}"
      
      products.each do |product|
        `cp #{product} ${CC_BUILD_ARTIFACTS}`
      end if (output_dir != nil && output_dir.length > 0)
    end
  end
end


class CLI < Clive
  opt :t, :target, arg: '<target_name>'
  opt :p, :profiles, arg: '<profile>...'
  opt :cert_password, arg: '<cert_password>'
  opt :o, :output_dir, arg: '<output_dir>'
  opt :k, :keychain, arg: '<keychain>'
  opt :keychain_password, arg: '<keychain-password>'
end

result = CLI.run

builder = XCBuild::Builder.new()

begin
  builder.build_and_package_configuration(result.args[0], result.args[1], result.args[2], result[:profiles], result[:output_dir], result[:cert_password], result[:keychain], result[:keychain_password], result[:target])
rescue Exception
  puts "BUILD FAILED: #{$!}"
  return -1
else
  puts "BUILD SUCCEEDED!"
end
