//
//  RTELayoutManager.h
//  RichTextEditor
//
//  Created by ChrisK on 7/21/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RTELayoutManager : NSLayoutManager

@property (nonatomic, strong) NSColor *bulletNumberingColor;
@property (nonatomic, assign) CGFloat bulletNumberingIndent;
@property (nonatomic, assign) CGFloat firstLineHeadIndent;

+ (NSString *)kBulletString;
+ (NSString *)kNumberingString;
+ (NSString *)kEncodedBulletString;
+ (NSString *)kEncodedNumberingString;

@end

@interface NSLayoutManager (RichTextEditor)

- (RTELayoutManager *)RTEInstance;

@end
