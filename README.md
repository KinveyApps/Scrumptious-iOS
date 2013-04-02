Scrumptious (Kinvey)
=====
This sample code shows how to modify Facebook's [Scrumptious Sample App](https://github.com/facebook/facebook-ios-sdk/tree/master/samples/Scrumptious) to use Kinvey to host Open Graph Objects and post actions to a user's timeline. Kinvey dynamically generates the Open Graph object html based upon the information chosen by the user. 

Scrumptious users post that they "ate" a meal, allowing them to tag where, when, and with whom they ate the meal, and attach a picture of the meal. 

## Using the Sample
The sample repository comes with the KinveyKit and Fracebook frameworks that it was developed against. In production code, you should update to the latest versions of these libraries.

* [Download KinveyKit](http://devcenter.kinvey.com/ios/downloads)
* [Download Facebook SDK](http://developers.facebook.com/ios/downloads/)

### Set-up the Backend
1. Create your Scrumptious App on Facebook.
    * Set up the "eat" action and "meal" object.
2. Create a new App on [Kinvey](https://console.kinvey.com/).
    1. Create a "meals" collection to store the data for each meal uploaded by the users.
    2. Set up mappings in the "Data Links" -> "Facebook Open Graph" settings. Follow the steps in [this tutorial](http://devcenter.kinvey.com/ios/tutorials/facebook-opengraph-tutorial) set up the mappings between the Kinvey object and the Facebook object.
         * You'll need to paste the "get code" for the meal object. This will set up some of the fields and settings for a `kinvey_scrumptious:meal` object type.
         * Map the following fields:
         	* `og:title` -> `selectedMeal`
         	* `og:image` -> `imageURL`
         	* `place:location:latitude` -> `latitude`
         	* `place:location:longitude` -> `longitude`
         * You will need to add additional mappings for these fields:
            * `og:determiner` -> `determiner`

    ![Field Mappings](https://raw.github.com/KinveyApps/Scrumptious-iOS/master/readme-mappings.png)            

    3. Add a new action `kinvey_scrumptious:eat` to represent the eat action.

### Set-up the App
1. In `SCAppDelegate application:didFinishLaunchingWithOptions:` enter your Kinvey app __App ID__ and __App Secret__.
2. In Scrumptioius-Info.plist, enter your __Facebook App ID__ in the `FacebookAppID` and `URL Schemes` values.

## Modifications to the Original Scrumptious
1. Created MealModel object to represent the OG meal object. This is used to store the meal's information in the Kinvey backend.
1. MealModel objects are populated with data chosen by the user in the interface, and then uploaded to Kinvey in three separate steps:
    1. Upload the image to Kinvey.
    2. Upload the data to Kinvey.
    3. Tell Kinvey to post the `eat` action to the user's timeline.
1. Added ability to take a picture of the meal.
1. Added additional OG fields, such as `determiner`, to improve the user experience.
1. Updated code to latest Objective-C syntax (Xcode 4.6). 

## Extending Scrumptious
* To add new meal types, just add the name to the `self.mealTypes` array created in `SCViewController.m`'s `viewDidLoad` method. You will also need to determiner to the `self.determiners` array at the same index. The determiner is the English indefinite article that corresponds to the meal name. This is used to make the OG action read like a normal sentence. For example "Bob ate _a_ Hotdog", "Jill ate _an_ Escargot", "Roger ate Mexican".
* To add new fields, add a property to `MealModel.h` and map that property to a backend field name in `MealModel.m`'s `hostToKinveyPropertyMapping` method. Then in the `FBOG` collection on the backend, map the field name to the Facebook Open Graph object field name. 

## Contact
Website: [www.kinvey.com](http://www.kinvey.com)

Support: [support@kinvey.com](http://docs.kinvey.com/mailto:support@kinvey.com)
