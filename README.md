Scrumptious (Kinvey)
=====
This sample code shows how to modify Facebook's [Scrumptious Sample App](https://github.com/facebook/facebook-ios-sdk/tree/master/samples/Scrumptious) to use Kinvey to host Open Graph Objects and post actions to a user's timeline. Kinvey dynamically generates the Open Graph object html based upon the information chosen by the user. This means it's easily extended and changeable.

Scrumptious users post that they "ate" a meal, allowing them to tag where, when, and with who they ate the meal, including the ability to take a picture of the meal. 

## Using the Sample
The sample repository comes with the KinveyKit and Fracebook frameworks that it was developed against. In production code, you should update to the latest versions of these libraries.

* [Download KinveyKit](http://devcenter.kinvey.com/ios/downloads)
* [Download Facebook SDK](http://developers.facebook.com/ios/downloads/)

### Set-up the Backend

## Modifications to the Original Scrumptious
1. Created MealModel object to represent the OG meal object. This is used to store the meal's information in the Kinvey backend.
1. MealModel objects are populated with data chosen by the user in the interface, and then uploaded to Kinvey in three separate steps:
    1. Upload the image to Kinvey.
    1. Upload the data to Kinvey.
    1. Tell Kinvey to post the `eat` action to the user's timeline.
1. Added ability to take a picture of the meal.
1. Added additional OG fields, such as `determiner`, to improve the user experience.
1. Updated code to latest Objective-C syntax (Xcode 4.6). 

## Extending Scrumptious
* To add new meal types, just add the name to the `self.mealTypes` array created in `SCViewController.m`'s `viewDidLoad` method. You will also need to determiner to the `self.determiners` array at the same index. The determiner is the English indefinite article that corresponds to the meal name. This is used to make the OG action read like a normal sentence. For example "Bob ate _a_ Hotdog", "Jill ate _an_ Escargot", "Roger ate Mexican".
* To add new fields, add a property to `MealModel.h` and map that property to a backend field name in `MealModel.m`'s `hostToKinveyPropertyMapping` method. Then in the `FBOG` collection on the backend, map the field name to the Facebook Open Graph object field name. 

## Contact
Website: [www.kinvey.com](http://www.kinvey.com)

Support: [support@kinvey.com](http://docs.kinvey.com/mailto:support@kinvey.com)