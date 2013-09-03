//
//  MealModel.m
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

#import "MealModel.h"

#import <KinveyKit/KinveyKit.h>


@implementation MealModel


+ (NSString *)generateUuidString
{
    return [[NSUUID UUID] UUIDString];
}

+ (MealModel *) newMealModel {
    MealModel *meal = [[MealModel alloc] init];
    meal.objectId = [self generateUuidString];
    return meal;
}

- (NSDictionary*) hostToKinveyPropertyMapping {
    return  @{
              @"objectId" : KCSEntityKeyId,
              @"imageId" : @"imageURL",
              @"imageName" : @"image",
              @"selectedMeal" : @"selectedMeal",
              @"url" : @"url",
              @"selectedFriends" : @"tags",
              @"selectedPlaceName" : @"place",
              @"location" : KCSEntityKeyGeolocation,
              @"latitude" : @"latitude",
              @"longitude" : @"longitude",
              @"determiner" : @"determiner"
              };
}

- (BOOL) isImageDownloaded
{
    return self.imagePath != nil;
}


@end




