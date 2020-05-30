#!/bin/sh

# $1 is your developer email
# $2 is your developer team ID
# run script: bash notarize_dmg.sh yourEmail@email.com ABCDEF1234

# remove previous folders
rm -rf archive
rm -rf app

xcodebuild archive \
  -project NotarizationDemo.xcodeproj \
  -scheme "NotarizationDemo" \
  -configuration Release \
  -archivePath archive/result.xcarchive

# create .app executable
xcodebuild archive \
  -archivePath archive/result.xcarchive \
  -exportArchive \
  -exportOptionsPlist exportOptions.plist \
  -exportPath app

# remove these so they are not packaged with the dmg
rm -rf app/Packaging.log
rm -rf app/DistributionSummary.plist
rm -rf app/ExportOptions.plist

hdiutil create -format UDZO -srcfolder app NotarizationDemo.dmg

echo "Uploading to notary service. This may take a moment..."
requestInfo=$(xcrun altool --notarize-app \
            --file "NotarizationDemo.dmg" \
            --username "$1" \
            --password "@keychain:notarization-password" \
            --asc-provider "$2" \
            --primary-bundle-id "stephenbodnar.NotarizationDemo")

uuid=$(ruby uuid.rb "$requestInfo")

current_status="in progress"
while [[ "$current_status" == "in progress" ]]; do
    sleep 15
    statusResponse=$(xcrun altool --notarization-info "$uuid" \
            --username "$1" \
            --password "@keychain:notarization-password")
    current_status=$(ruby status.rb "$statusResponse")
done

if [[ "$current_status" != "success" ]]; then
  echo "Error! The status was $current_status"
  exit 1
else
  xcrun stapler staple "NotarizationDemo.dmg"

  # Now you have your stapled DMG, distribute as you like

  echo "Success!"
fi