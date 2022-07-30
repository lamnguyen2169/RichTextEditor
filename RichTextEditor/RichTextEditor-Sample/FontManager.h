//
//  FontManager.h
//  macOSRTESample
//
//  Created by ChrisK on 7/5/22.
//  Copyright (c) 2022 ChrisK. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface FontManager : NSObject

// MARK: -

@property (nonatomic, strong, readonly) NSArray<NSFont *> *availableFonts;

// MARK: -

+ (FontManager *)sharedManager;
+ (void)startUp;

@end

NS_ASSUME_NONNULL_END
