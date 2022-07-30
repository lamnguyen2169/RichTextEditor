//
//  FontManager.h
//  macOSRTESample
//
//  Created by lam1611 on 7/5/22.
//  Copyright © 2022 Pikle Productions. All rights reserved.
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
