# Using Github Actions + FastLane to deploy to TestFlight

These instructions allow you to build FreeAPS X without having access to a Mac. They also allow you to easily install FreeAPS X on phones that are not connected to your computer. So you can send builds and updates to those you care for easily, or have an easy to access backup if you run FreeAPS X for yourself. You do not need to worry about correct Xcode/Mac versions either. An app built using this method can easily be deployed to newer versions of iOS, as soon as they are available.

The setup steps are somewhat involved, but nearly all are one time steps. Subsequent builds are trivial.  Note that TestFlight requires apple id accounts 13 years or older. Your app must be updated once every 90 days, but it's a simple click to make a new build and can be done from anywhere.

## Prerequisites

* A [github account](https://github.com/signup). The free level comes with plenty of storage and free compute time to build FreeAPS X, multiple times a day, if you wanted to.
* A paid [Apple Developer account](https://developer.apple.com). You may be able to use the free version, but that has not been tested.
* Some time. Set aside a couple of hours to perform the setup.


## Generate App Store Connect API Key

1. Sign in to the [Apple developer portal page](https://developer.apple.com/account/resources/certificates/list).
1. Copy the team id from the upper right of the screen. Record this as your `TEAMID`.
1. Go to the [App Store Connect](https://appstoreconnect.apple.com/access/api) interface, click the "Keys" tab, and create a new key with "Admin" access. Give it a name like "FastLane API Key".
1. Record the key id; this will be used for `FASTLANE_KEY_ID`.
1. Record the issuer id; this will be used for `FASTLANE_ISSUER_ID`.
1. Download the API key itself, and open it in a text editor. The contents of this file will be used for `FASTLANE_KEY`. Copy the full text, including the "-----BEGIN PRIVATE KEY-----" and "-----END PRIVATE KEY-----" lines.

## Setup Github
1. Create a [new empty repository](https://github.com/new) titled `Match-Secrets`. It should be private.
1. Fork https://github.com/Jon-b-m/freeaps into your account. If you already have a fork of FreeAPS X in GitHub, you can't make another one. You can continue to work with your existing fork, or delete that from GitHub and then and fork https://github.com/Jon-b-m/freeaps.
1. Create a [new personal access token](https://github.com/settings/tokens/new):
    * Enter a name for your token. Something like "FastLane Access Token".
    * 30 days is fine, or you can select longer if you'd like.
    * Select the `repo` permission scope.
    * Click "Generate token".
    * Copy the token and record it. It will be used below as `GH_PAT`.
1. In the forked FreeAPS X repo, go to Settings -> Secrets -> Actions.
1. For each of the following secrets, tap on "New repository secret", then add the name of the secret, along with the value you recorded for it:
    * `TEAMID`
    * `FASTLANE_KEY_ID`
    * `FASTLANE_ISSUER_ID`
    * `FASTLANE_KEY`
    * `GH_PAT`
    * `MATCH_PASSWORD` - just make up a password for this

## Add Identifiers for FreeAPS X App

1. Click on the "Actions" tab of your FreeAPS X repository.
1. Select "Add Identifiers".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Create App Group

If you have already built FreeAPS X via Xcode using this Apple ID, you can skip on to [Create FreeAPS X App in App Store Connect](#create-FreeAPS-X-app-in-app-store-connect).
_Please note that in default builds of FreeAPS X, the app group is actually identical to the one used with Loop, so please enter these details exactly as described below. This is to ease the setup of apps such as Xdrip4iOS. It may require some caution if transfering between FreAPS X and Loop._

1. Go to [Register an App Group](https://developer.apple.com/account/resources/identifiers/applicationGroup/add/) on the apple developer site.
1. For Description, use "Loop App Group".
1. For Identifier, enter "group.com.TEAMID.loopkit.LoopGroup", subsituting your team id for `TEAMID`.
1. Click "Continue" and then "Register".

## Add App Group to Bundle Identifiers

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) on the apple developer site.
1. For each of the following identifier names:
    * FreeeAPS
    * FreeAPS watchkitapp
    * FreeAPS watchkitapp watchkitextension
1. Click on the identifier's name.
1. On the "App Groups" capabilies, click on the "Configure" button.
1. Select the "Loop App Group" _(yes, "Loop App Group" is correct)_
1. Click "Continue".
1. Click "Save".
1. Click "Confirm".
1. Remember to do this for each of the identifiers above.

## Create FreeAPS X App in App Store Connect

If you have created a FreeAPS X app in App Store Connect before, you can skip this section as well.

1. Go to the [apps list](https://appstoreconnect.apple.com/apps) on App Store Connect and click the blue "plus" icon to create a New App.
    * Select "iOS".
    * Select a name: this will have to be unique, so you may have to try a few different names here, but it will not be the name you see on your phone, so it's not that important.
    * Select your primary language.
    * Choose the bundle ID that matches `ru.artpancreas.TEAMID.FreeAPS`, with TEAMID matching your team id.
    * SKU can be anything; e.g. "123".
    * Select "Full Access".
1. Click Create

You do not need to fill out the next form. That is for submitting to the app store.

## Create Building Certficates

1. Go back to the "Actions" tab of your FreeAPS X repository in github.
1. Select "Create Certificates".
1. Click "Run Workflow", and tap the green button.
1. Wait, and within a minute or two you should see a green checkmark indicating the workflow succeeded.

## Build FreeAPS X!

1. Click on the "Actions" tab of your FreeAPS X repository.
1. Select "Build FAX". _Are you working on a previuos fork of FreeAPS X and not seeing any GitHub workflows in the Actions tab? You may have to change the default branch so that it contains the .github/workflows files, or merge these changes into your default branch (typically `master`)._
1. Click "Run Workflow", select your branch, and tap the green button.
1. You have some time now. Go enjoy a coffee. The build should take about 15 minutes.
1. Your app should eventually appear on [App Store Connect](https://appstoreconnect.apple.com/apps).
1. For each phone/person you would like to support FreeAPS X on:
    * Add them in [Users and Access](https://appstoreconnect.apple.com/access/users) on App Store Connect.
    * Add them to your TestFlight Internal Testing group.
