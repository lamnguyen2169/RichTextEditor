//
//  RTEFontManager.h
//  RichTextEditor
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RTEFontManager : NSObject

// MARK: -

@property (nonatomic, strong, readonly) NSArray<NSFont *> *availableFonts;

// MARK: -

+ (RTEFontManager *)sharedManager;
+ (void)startUp;

@end
