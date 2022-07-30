//
//  RTELayoutManager.h
//  RichTextEditor
//
//  Created by ChrisK on 7/21/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RTELayoutManager : NSLayoutManager

+ (NSString *)kBulletString;
+ (NSString *)kNumberingString;
+ (NSString *)indentationString;

@end
