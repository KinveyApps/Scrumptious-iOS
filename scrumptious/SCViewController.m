/*
 * Copyright 2012 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/*
 * Copyright 2013 Kinvey, Inc
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SCViewController.h"
#import "SCAppDelegate.h"
#import "SCLoginViewController.h"
#import <AddressBook/AddressBook.h>
#import "TargetConditionals.h"
#import <KinveyKit/KinveyKit.h>
#import "MealModel.h"

typedef enum ROWS : NSInteger {
    MEAL, PLACE, FRIENDS, PICTURE
} ROWS;

@interface SCViewController() < UITableViewDataSource,
FBFriendPickerDelegate,
UINavigationControllerDelegate,
FBPlacePickerDelegate,
CLLocationManagerDelegate,
UIActionSheetDelegate,
UIImagePickerControllerDelegate>

@property (strong, nonatomic) FBUserSettingsViewController *settingsViewController;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *userProfileImage;
@property (strong, nonatomic) IBOutlet UILabel *userNameLabel;
@property (strong, nonatomic) IBOutlet UIButton *announceButton;
@property (strong, nonatomic) IBOutlet UITableView *menuTableView;
@property (strong, nonatomic) UIActionSheet *mealPickerActionSheet;
@property (strong, nonatomic) NSArray *mealTypes;
@property (strong, nonatomic) NSArray *determinerTypes;

@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) FBCacheDescriptor *placeCacheDescriptor;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@property (strong, nonatomic) KCSAppdataStore *kinveyStore;
@property (strong, nonatomic) KCSResourceResponse *result;
@property (strong, nonatomic) UIImage *foodPicture;
@property (nonatomic, strong) MealModel *mealModel;
@property (strong, nonatomic) UIPopoverController *popover;

@end

@implementation SCViewController

#pragma mark - View Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Scrumptious";
    
    
    
    // Get the CLLocationManager going.
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    // We don't want to be notified of small changes in location, preferring to use our
    // last cached results, if any.
    self.locationManager.distanceFilter = 50;
    
    // This avoids a gray background in the table view on iPad.
    if ([self.menuTableView respondsToSelector:@selector(backgroundView)]) {
        self.menuTableView.backgroundView = nil;
    }
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithTitle:@"Settings"
                                              style:UIBarButtonItemStyleBordered
                                              target:self
                                              action:@selector(settingsButtonWasPressed:)];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sessionStateChanged:)
                                                 name:SCSessionStateChangedNotification
                                               object:nil];
    
    self.mealTypes = @[@"Cheeseburger",
                       @"Pizza",
                       @"Hotdog",
                       @"Italian",
                       @"French",
                       @"Chinese",
                       @"Thai",
                       @"Indian"];
    self.determinerTypes = @[@"a",
                             @"a",
                             @"a",
                             @"",
                             @"",
                             @"",
                             @"",
                             @""];
    
    
    // First create the Open Graph meal object for the meal we ate.
    [self resetMeal];
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    if (FBSession.activeSession.isOpen) {
        [self populateUserDetails];
    }
}

-(void)settingsButtonWasPressed:(id)sender {
    if (self.settingsViewController == nil) {
        self.settingsViewController = [[FBUserSettingsViewController alloc] init];
        self.settingsViewController.delegate = self;
    }
    [self.navigationController pushViewController:self.settingsViewController animated:YES];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // Release any retained subviews of the main view.
    self.mealPickerActionSheet = nil;
    
    _locationManager.delegate = nil;
    _mealPickerActionSheet.delegate = nil;
}


#pragma mark - Open graph / Data Model

- (void) resetMeal
{
    self.mealModel = [[MealModel alloc] init];
}

- (void) updateModelWithPlace:(id<FBGraphPlace>)selectedPlace
{
    // FBSample logic
    // We don't use the action.place syntax here because, unfortunately, setPlace:
    // and a few other selectors may be flagged as reserved selectors by Apple's App Store
    // validation tools. While this doesn't necessarily block App Store approval, it
    // could slow down the approval process. Falling back to the setObjec:forKey:
    // selector is a useful technique to avoid such naming conflicts.
    self.mealModel.selectedPlaceName = selectedPlace.name;
    self.mealModel.selectedPlace = selectedPlace;
    self.mealModel.location = @[selectedPlace.location.longitude, selectedPlace.location.latitude];
    self.mealModel.latitude = selectedPlace.location.latitude,
    self.mealModel.longitude = selectedPlace.location.longitude;
}

// FBSample logic
// Creates the Open Graph Action.
- (void)postOpenGraphAction {
    
    
    KCSCollection* collection = [KCSCollection collectionFromString:@"Eating" ofClass:[MealModel class]];
    _kinveyStore = [KCSCachedStore storeWithCollection:collection options:@{ KCSStoreKeyCachePolicy : @(KCSCachePolicyNetworkFirst)}];
    
    
    // Now create an Open Graph eat action with the meal, our location, and the people we were with.
    if (self.foodPicture != nil){
        //generate a unique name for the new image, since Kinvey has a flat namespace for resources)
        NSString *imageName = [self.userNameLabel.text stringByAppendingString:[MealModel generateUuidString]];
        imageName = [imageName stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *path = [NSString stringWithFormat:@"%@.jpg", imageName];
        
        //Convert the UIImage to JPEG data
        NSData *imageData = UIImageJPEGRepresentation(self.foodPicture, 0.9);
        [KCSFileStore uploadData:imageData options:@{KCSFileFileName : path} completionBlock:^(KCSFile *uploadInfo, NSError *error) {
            if (error == nil) {
                self.mealModel.imageId = [uploadInfo fileId];
                [self uploadToKinvey:self.mealModel];
            } else {
                NSLog(@"resourceService failed with error %@.", error);
            }
        } progressBlock:nil];
    }else{
        //there is no image, so just upload to kinvey
        [self uploadToKinvey:self.mealModel];
        
    }
}

- (void) uploadToKinvey:(MealModel*) mealObject{
    [_kinveyStore saveObject: mealObject withCompletionBlock:^(NSArray *objectsOrNil, NSError *errorOrNil) {
        [self.activityIndicator stopAnimating];
        [self.view setUserInteractionEnabled:YES];
        if (errorOrNil != nil) {
            NSLog(@" entity:(id)%@ save error: (NSError *)%@", mealObject, errorOrNil);
        } else {
            NSLog(@" entity:(id)%@ completed", mealObject);
            [self pushToOpenGraph: mealObject];
            
        }
    } withProgressBlock:nil];
    
}



- (void) pushToOpenGraph:(MealModel*) mealObject
{
    //turn the array of FB friends objects into an array of just their id's
    NSMutableArray* friends = [NSMutableArray arrayWithCapacity:mealObject.selectedFriends.count];
    for (NSDictionary* f in mealObject.selectedFriends){
        [friends addObject: f[@"id"]];
    }
    
    NSMutableDictionary* params = [NSMutableDictionary dictionary];
    if (friends.count > 0) {
        params[@"tags"] = friends;
    }
    if (mealObject.selectedPlace) {
        params[@"place"] = mealObject.selectedPlace.id;
    }
    
    //Kinvey's Open Graph collection just needs a small amount of data to post the OG action, the rest comes from the defined mappings between the meal collection and open graph.
    [KCSFacebookHelper publishToOpenGraph:mealObject.objectId  //the entity's KCSEntityKeyId
                                   action:@"kinvey_scrumptious:eat" // the action type
                               objectType:@"kinvey_scrumptious:meal" //the objectType
                           optionalParams:params
                               completion:^(NSString *actionId, NSError *errorOrNil) {
                                   NSLog(@"Finished publshing story. ID: %@, error (if any) = %@", actionId, errorOrNil);
                                   
                                   if (errorOrNil == nil) {
                                       [[[UIAlertView alloc] initWithTitle:@"Result"
                                                                   message:[NSString stringWithFormat:@"Posted Open Graph action, id: %@",
                                                                            actionId]
                                                                  delegate:nil
                                                         cancelButtonTitle:@"Thanks!"
                                                         otherButtonTitles:nil]
                                        show];
                                       
                                       // start over
                                       self.foodPicture = nil;
                                       [self resetMeal];
                                       [self.menuTableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow:3 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
                                       [self updateSelections];
                                   } else {
                                       [[[UIAlertView alloc] initWithTitle:@"Something Went Wrong"
                                                                   message:errorOrNil.localizedDescription                                                                  delegate:nil
                                                         cancelButtonTitle:@"OK"
                                                         otherButtonTitles:nil] show];
                                   }
                               }];
}


// FBSample logic
// Handles the user clicking the Announce button by creating an Open Graph Action
- (IBAction)announce:(id)sender {
    // if we don't have permission to announce, let's first address that
    if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound) {
        
        [FBSession.activeSession requestNewPublishPermissions:@[@"publish_actions"]
                                              defaultAudience:FBSessionDefaultAudienceFriends
                                            completionHandler:^(FBSession *session, NSError *error) {
                                                if (!error) {
                                                    // re-call assuming we now have the permission
                                                    [self announce:sender];
                                                }
                                            }];
    } else {
        self.announceButton.enabled = false;
        [self centerAndShowActivityIndicator];
        [self.view setUserInteractionEnabled:NO];
        
        [self postOpenGraphAction];
    }
}

- (void)startLocationManager {
    [self.locationManager startUpdatingLocation];
}

- (void)centerAndShowActivityIndicator {
    CGRect frame = self.view.frame;
    CGPoint center = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    self.activityIndicator.center = center;
    [self.activityIndicator startAnimating];
}

#pragma mark UIActionSheetDelegate methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    
    // If user presses cancel, do nothing
    if (buttonIndex == actionSheet.cancelButtonIndex)
        return;
    
    // One method handles the delegate action for two action sheets
    if (actionSheet == self.mealPickerActionSheet) {
        self.mealModel.selectedMeal = (self.mealTypes)[buttonIndex];
        NSString* determiner = (self.determinerTypes)[buttonIndex];
        if (determiner.length > 0){
            self.mealModel.determiner = determiner;
        }
        
        [self updateSelections];
    }
}


#pragma mark -

#pragma mark Data fetch

-(NSString *)documentsDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = paths[0];
    return documentsDirectoryPath;
}

- (void)updateCellIndex:(int)index withSubtitle:(NSString *)subtitle {
    UITableViewCell *cell = (UITableViewCell *)[self.menuTableView cellForRowAtIndexPath:
                                                [NSIndexPath indexPathForRow:index inSection:0]];
    cell.detailTextLabel.text = subtitle;
}

- (void)updateSelections {
    [self updateCellIndex:MEAL withSubtitle:(self.mealModel.selectedMeal ?
                                             self.mealModel.selectedMeal :
                                             @"Select one")];
    [self updateCellIndex:PLACE withSubtitle:(self.mealModel.selectedPlace ?
                                              self.mealModel.selectedPlace.name :
                                              @"Select one")];
    
    NSString *friendsSubtitle = @"Select friends";
    int friendCount = self.mealModel.selectedFriends.count;
    if (friendCount > 2) {
        // Just to mix things up, don't always show the first friend.
        id<FBGraphUser> randomFriend = self.mealModel.selectedFriends[arc4random() % friendCount];
        friendsSubtitle = [NSString stringWithFormat:@"%@ and %d others", randomFriend.name, friendCount - 1];
    } else if (friendCount == 2) {
        id<FBGraphUser> friend1 = self.mealModel.selectedFriends[0];
        id<FBGraphUser> friend2 = self.mealModel.selectedFriends[1];
        friendsSubtitle = [NSString stringWithFormat:@"%@ and %@", friend1.name, friend2.name];
    } else if (friendCount == 1) {
        id<FBGraphUser> friend = self.mealModel.selectedFriends[0];
        friendsSubtitle = friend.name;
    }
    [self updateCellIndex:FRIENDS withSubtitle:friendsSubtitle];
    
    self.announceButton.enabled = (self.mealModel.selectedMeal != nil);
}

// FBSample logic
// Displays the user's name and profile picture so they are aware of the Facebook
// identity they are logged in as.
- (void)populateUserDetails {
    if (FBSession.activeSession.isOpen) {
        [[FBRequest requestForMe] startWithCompletionHandler:
         ^(FBRequestConnection *connection, NSDictionary<FBGraphUser> *user, NSError *error) {
             if (!error) {
                 self.userNameLabel.text = user.name;
                 self.userProfileImage.profileID = user[@"id"];
             }
         }];
    }
}


- (void)sessionStateChanged:(NSNotification*)notification {
    // A more complex app might check the state to see what the appropriate course of
    // action is, but our needs are simple, so just make sure our idea of the session is
    // up to date and repopulate the user's name and picture (which will fail if the session
    // has become invalid).
    [self populateUserDetails];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)setPlaceCacheDescriptorForCoordinates:(CLLocationCoordinate2D)coordinates {
    self.placeCacheDescriptor =
    [FBPlacePickerViewController cacheDescriptorWithLocationCoordinate:coordinates
                                                        radiusInMeters:1000
                                                            searchText:@"restaurant"
                                                          resultsLimit:50
                                                      fieldsForRequest:nil];
}

#pragma mark - FBUserSettingsDelegate methods

- (void)loginViewController:(id)sender receivedError:(NSError *)error{
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error: %@",
                                                                     [SCAppDelegate FBErrorCodeDescription:error.code]]
                                                            message:error.localizedDescription
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}

#pragma mark UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 4;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = (UITableViewCell*)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.textLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        cell.textLabel.lineBreakMode = UILineBreakModeTailTruncation;
        cell.textLabel.clipsToBounds = YES;
        
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:0.6 blue:0.8 alpha:1];
        cell.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
        cell.detailTextLabel.clipsToBounds = YES;
    }
    
    switch (indexPath.row) {
        case MEAL:
            cell.textLabel.text = @"What are you eating?";
            cell.detailTextLabel.text = @"Select one";
            cell.imageView.image = [UIImage imageNamed:@"action-eating.png"];
            break;
            
        case PLACE:
            cell.textLabel.text = @"Where are you?";
            cell.detailTextLabel.text = @"Select one";
            cell.imageView.image = [UIImage imageNamed:@"action-location.png"];
            break;
            
        case FRIENDS:
            cell.textLabel.text = @"With whom?";
            cell.detailTextLabel.text = @"Select friends";
            cell.imageView.image = [UIImage imageNamed:@"action-people.png"];
            break;
        case PICTURE:
            cell.textLabel.text = @"How's it look?";
            if (self.foodPicture == nil){
                cell.imageView.image = [UIImage imageNamed:@"camera"];
                cell.detailTextLabel.text = @"Take a picture";
            } else{
                cell.imageView.image = self.foodPicture;
                cell.detailTextLabel.text = @"Picture selected";
            }
            
            break;
            
        default:
            break;
    }
    
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIViewController *target;
    
    switch (indexPath.row) {
        case MEAL: {
            self.mealPickerActionSheet = [[UIActionSheet alloc] initWithTitle:@"Select a meal"
                                                                     delegate:self
                                                            cancelButtonTitle:nil
                                                       destructiveButtonTitle:nil
                                                            otherButtonTitles:nil];
            
            for (NSString *meal in self.mealTypes) {
                [self.mealPickerActionSheet addButtonWithTitle:meal];
            }
            
            self.mealPickerActionSheet.cancelButtonIndex = [self.mealPickerActionSheet addButtonWithTitle:@"Cancel"];
            
            [self.mealPickerActionSheet showInView:self.view];
            return;
        }
            
        case PLACE: {
            FBPlacePickerViewController *placePicker = [[FBPlacePickerViewController alloc] init];
            placePicker.title = @"Select a restaurant";
            
            // SIMULATOR BUG:
            // See http://stackoverflow.com/questions/7003155/error-server-did-not-accept-client-registration-68
            // at times the simulator fails to fetch a location; when that happens rather than fetch a
            // a meal near 0,0 -- let's see if we can find something good in Paris
            if (self.placeCacheDescriptor == nil) {
                [self setPlaceCacheDescriptorForCoordinates:CLLocationCoordinate2DMake(48.857875, 2.294635)];
            }
            
            [placePicker configureUsingCachedDescriptor:self.placeCacheDescriptor];
            [placePicker loadData];
            [placePicker presentModallyFromViewController:self
                                                 animated:YES
                                                  handler:^(FBViewController *sender, BOOL donePressed) {
                                                      if (donePressed) {
                                                          [self updateModelWithPlace:placePicker.selection];
                                                          [self updateSelections];
                                                      }
                                                      
                                                  }];
            return;
        }
            
        case FRIENDS: {
            FBFriendPickerViewController *friendPicker = [[FBFriendPickerViewController alloc] init];
            
            // Set up the friend picker to sort and display names the same way as the
            // iOS Address Book does.
            
            // Need to call ABAddressBookCreate in order for the next two calls to do anything.
            ABAddressBookRef ab = ABAddressBookCreateWithOptions(NULL, NULL);
            if (ab != NULL) {
                ABPersonSortOrdering sortOrdering = ABPersonGetSortOrdering();
                ABPersonCompositeNameFormat nameFormat = ABPersonGetCompositeNameFormat();
                
                friendPicker.sortOrdering = (sortOrdering == kABPersonSortByFirstName) ? FBFriendSortByFirstName : FBFriendSortByLastName;
                friendPicker.displayOrdering = (nameFormat == kABPersonCompositeNameFormatFirstNameFirst) ? FBFriendDisplayByFirstName : FBFriendDisplayByLastName;
                CFRelease(ab);
            }
            
            [friendPicker loadData];
            [friendPicker presentModallyFromViewController:self
                                                  animated:YES
                                                   handler:^(FBViewController *sender, BOOL donePressed) {
                                                       if (donePressed) {
                                                           NSArray* friends = friendPicker.selection;
                                                           if (friends.count > 0) {
                                                               self.mealModel.selectedFriends = friends;
                                                           } else {
                                                               self.mealModel = nil; //clear out friends if none picked
                                                           }
                                                           [self updateSelections];
                                                       }
                                                   }];
            
            return;
        }
            
        case PICTURE: {
            
            UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
            if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]){
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                    self.popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
                    UIImageView *v = [tableView cellForRowAtIndexPath:indexPath].imageView;
                    [self.popover presentPopoverFromRect:v.bounds inView:v permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
                }else{
                    [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
                    [self presentModalViewController:imagePicker animated:YES];
                    
                }
            } else  {
                [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                [self presentModalViewController:imagePicker animated:YES];
                
            }
            
            [imagePicker setDelegate:self];
            
            
            return;
            
        }
    }
    
    [self.navigationController pushViewController:target animated:YES];
}


-(void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    self.foodPicture = info[UIImagePickerControllerOriginalImage];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self.popover dismissPopoverAnimated:true];
    } else {
        [self dismissModalViewControllerAnimated:YES];
    }
    
    [self.menuTableView reloadRowsAtIndexPaths: @[[NSIndexPath indexPathForRow:PICTURE inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
}



#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    if (!oldLocation ||
        (oldLocation.coordinate.latitude != newLocation.coordinate.latitude &&
         oldLocation.coordinate.longitude != newLocation.coordinate.longitude &&
         newLocation.horizontalAccuracy <= 100.0)) {
            // Fetch data at this new location, and remember the cache descriptor.
            [self setPlaceCacheDescriptorForCoordinates:newLocation.coordinate];
            [self.placeCacheDescriptor prefetchAndCacheForSession:FBSession.activeSession];
        }
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
	NSLog(@"Location Manager failed: %@", error);
}

@end
