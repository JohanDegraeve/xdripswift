#!/bin/bash

if [ -f ./xdrip.xcodeproj/project.pbxproj ]
then
	sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = "net.johandegraeve.xdripswift.xDrip4iOS-Widget";/PRODUCT_BUNDLE_IDENTIFIER = "com.${DEVELOPMENT_TEAM}.xdripswift.xDrip4iOS-Widget";/g' ./xdrip.xcodeproj/project.pbxproj
	sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = net.johandegraeve.xdripswift;/PRODUCT_BUNDLE_IDENTIFIER = "com.${DEVELOPMENT_TEAM}.xdripswift";/g' ./xdrip.xcodeproj/project.pbxproj
	sed -i '' 's/DEVELOPMENT_TEAM = RNX44PP998;/DEVELOPMENT_TEAM = "";/g' ./xdrip.xcodeproj/project.pbxproj
else
	echo "target file './xdrip.xcodeproj/project.pbxproj' not found!"
fi
