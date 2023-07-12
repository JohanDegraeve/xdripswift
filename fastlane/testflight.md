# Using Github Actions + FastLane to deploy to TestFlight

These instructions allow you to build xDrip4iOS without having access to a Mac.

* You can install xDrip4iOS on phones via TestFlight that are not connected to your computer
* You can send builds and updates to those you care for
* You can install xDrip4iOS on your phone using only the TestFlight app if a phone was lost or the app is accidentally deleted
* You do not need to worry about specific Xcode/Mac versions for a given iOS

The setup steps are somewhat involved, but nearly all are one time steps. Subsequent builds are trivial. Your app must be updated once every 90 days, but it's a simple click to make a new build and can be done from anywhere. The 90-day update is a TestFlight requirement, which can be automated.

This method for building without a Mac was ported from Loop. If you have used this method for Loop or one of the other DIY apps (Loop Caregiver, Loop Follow or iAPS), some of the steps can be re-used and the full set of instructions does not need to be repeated. This will be mentioned in relevant sections below.

There are more detailed instructions in LoopDocs for using GitHub for Browser Builds of Loop, including troubleshooting and build errors. Please refer to:

* [LoopDocs: GitHub Overview](https://loopkit.github.io/loopdocs/gh-actions/gh-overview/)
* [LoopDocs: GitHub Errors](https://loopkit.github.io/loopdocs/gh-actions/gh-errors/)

Note that installing with TestFlight, (in the US), requires the Apple ID account holder to be 13 years or older. For younger users, an adult must log into Media & Purchase on the child's phone to install Loop. More details on this can be found in [LoopDocs](https://loopkit.github.io/loopdocs/gh-actions/gh-deploy/#install-testflight-loop-for-child).

## Prerequisites

* A [github account](https://github.com/signup). The free level comes with plenty of storage and free compute time to build Xdrip4iOS, multiple times a day, if you wanted to.
* A paid [Apple Developer account](https://developer.apple.com). You may be able to use the free version, but that has not been tested.
* Some time. Set aside a couple of hours to perform the setup. 
* Use the same GitHub account for all "Browser Builds" of the various DIY apps.

## Generate App Store Connect API Key

This step is common for all "Browser Builds", and should be done ony once. Please save the API key somewhere safe, so it can be re-used for other builds, or if needing to start from scratch.

1. Sign in to the [Apple developer portal page](https://developer.apple.com/account/resources/certificates/list).
1. Copy the team id from the upper right of the screen. Record this as your `TEAMID`.
1. Go to the [App Store Connect](https://appstoreconnect.apple.com/access/api) interface, click the "Keys" tab, and create a new key with "Admin" access. Give it a name like "FastLane API Key".
1. Record the key id; this will be used for `FASTLANE_KEY_ID`.
1. Record the issuer id; this will be used for `FASTLANE_ISSUER_ID`.
1. Download the API key itself, and open it in a text editor. The contents of this file will be used for `FASTLANE_KEY`. Copy the full text, including the "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" lines.

## Setup Github Match-Secrets repository

This is also a common step for all "browser builds", do this step only once
1. Create a [new empty repository](https://github.com/new) titled `Match-Secrets`. It should be private.

## Setup Github xdripswift repository
1. Fork https://github.com/JohanDegraeve/xdripswift into your account. If you already have a fork of Xdrip4iOS in GitHub, you can't make another one. You can continue to work with your existing fork, or delete that from GitHub and then and fork https://github.com/JohanDegraeve/xdripswift.

If you have previously built Loop or another app using the "browser build" method, you can can re-use your previous personal access token (`GH_PAT`) and skip ahead to `step 2`.
1. Create a [new personal access token](https://github.com/settings/tokens/new):
    * Enter a name for your token. Something like "FastLane Access Token".
    * Change the Expiration selection to `No expiration`.
    * Select the `repo` and `workflow` permission scopes.
    * Click "Generate token".
    * Copy the token and record it. It will be used below as `GH_PAT`.
1. In the forked Xdrip4iOS repo, go to Settings -> Secrets -> Actions.
1. For each of the following secrets, tap on "New repository secret", then add the name of the secret, along with the value you recorded for it:
    * `TEAMID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD` - just make up a password for this

## Validate repository secrets

1. Click on the "Actions" tab of your Xdrip4iOS repository.
1. Select "1. Validate Secrets".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.
1. The workflow will check if the required secrets are added and that they are correctly formatted. If errors are detected, please check the run log for details. 

## Add Identifiers for Xdrip4iOS App

1. Click on the "Actions" tab of your Xdrip4iOS repository.
1. Select "2. Add Identifiers".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Create App Group

If you have already built Xdrip4iOS via Xcode using this Apple ID, you can skip on to [Create Xdrip4iOS App in App Store Connect](#create-Xdrip4iOS-app-in-app-store-connect).
_Please note that in default builds of Xdrip4iOS, the app group is actually identical to the one used with Loop, so please enter these details exactly as described below. This is to ease the setup of apps such as Loop or FreeAPS X. It may require some caution if transfering between FreAPS X and Loop._

1. Go to [Register an App Group](https://developer.apple.com/account/resources/identifiers/applicationGroup/add/) on the apple developer site.
1. For Description, use "Loop App Group".
1. For Identifier, enter "group.com.TEAMID.loopkit.LoopGroup", subsituting your team id for `TEAMID`.
1. Click "Continue" and then "Register".

## Add App Group to Bundle Identifiers

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) on the apple developer site.
1. For each of the following identifier names:
    * xdripswift
    * xdripswift xDrip4iOS-Widget
    * Watch App
    * Watch App WatchKit Extension
1. Click on the identifier's name.
1. On the "App Groups" capabilies, click on the "Configure" button.
1. Select the "Loop App Group" _(yes, "Loop App Group" is correct)_
1. Click "Continue".
1. Click "Save".
1. Click "Confirm".
1. Remember to do this for each of the identifiers above.

## Create Xdrip4iOS App in App Store Connect

If you have created a Xdrip4iOS app in App Store Connect before, you can skip this section as well.

1. Go to the [apps list](https://appstoreconnect.apple.com/apps) on App Store Connect and click the blue "plus" icon to create a New App.
    * Select "iOS".
    * Select a name: this will have to be unique, so you may have to try a few different names here, but it will not be the name you see on your phone, so it's not that important.
    * Select your primary language.
    * Choose the bundle ID that matches `com.TEAMID.xdripswift`, with TEAMID matching your team id.
    * SKU can be anything; e.g. "123".
    * Select "Full Access".
1. Click Create

You do not need to fill out the next form. That is for submitting to the app store.

## Create Building Certficates

1. Go back to the "Actions" tab of your Xdrip4iOS repository in github.
1. Select "3. Create Certificates".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Build Xdrip4iOS!

1. Click on the "Actions" tab of your Xdrip4iOS repository.
1. Select "4. Build Xdrip4iOS". _Are you working on a previuos fork of Xdrip4iOS and not seeing any GitHub workflows in the Actions tab? You may have to change the default branch so that it contains the .github/workflows files, or merge these changes into your default branch (typically `master`)._
1. Click "Run Workflow", select your branch, and tap the green button.
1. You have some time now. Go enjoy a coffee. The build should take about 15 minutes.
1. Your app should eventually appear on [App Store Connect](https://appstoreconnect.apple.com/apps).
1. For each phone/person you would like to support Xdrip4iOS on:
    * Add them in [Users and Access](https://appstoreconnect.apple.com/access/users) on App Store Connect.
    * Add them to your TestFlight Internal Testing group.
