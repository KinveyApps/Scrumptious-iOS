//
//  MealModel.h
//  Scrumptious-Kinvey
//
//  Created by Edward Fleming
//  Copyright 2013 Kinvey, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import <Foundation/Foundation.h>
#import <FacebookSDK/FacebookSDK.h>

@interface MealModel : NSObject 


@property (strong, nonatomic) NSString *objectId;

@property (strong, nonatomic) NSString *url;
@property (strong, nonatomic) NSString *imageURL;
@property (strong, nonatomic) NSArray *selectedFriends;
@property (strong, nonatomic) id<FBGraphPlace> selectedPlace;
@property (strong, nonatomic) NSString *selectedPlaceName;
@property (nonatomic, copy) NSString* imageName;
@property (strong, nonatomic) NSString *imagePath;
@property (strong, nonatomic) NSString *selectedMeal;
@property (strong, nonatomic) NSArray *location;
@property (strong, nonatomic) NSNumber *latitude;
@property (strong, nonatomic) NSNumber *longitude;
@property (strong, nonatomic) NSString *determiner;

+ (NSString *)generateUuidString;




@end